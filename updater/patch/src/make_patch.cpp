#include "dashpod_patch/patch.h"

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <stdexcept>
#include <string>
#include <vector>

#include <zstd.h>

namespace dashpod::patch {

namespace {

using Idx = std::int64_t;

// ---------------------------------------------------------------------------
// Suffix array of `data[0..n]`. Indices sorted lexicographically.
// std::sort with a memcmp comparator — O(n log n × n) worst case, but the
// constant factor is small and the typical case (mostly-distinct prefixes)
// behaves like O(n log n × k) for a small k. Adequate for patch inputs up
// to a few tens of MB. For larger inputs, swap in SA-IS or libdivsufsort.
// ---------------------------------------------------------------------------
std::vector<Idx> build_suffix_array(const std::uint8_t* data, Idx n) {
    std::vector<Idx> sa(static_cast<std::size_t>(n));
    for (Idx i = 0; i < n; ++i) sa[static_cast<std::size_t>(i)] = i;
    std::sort(sa.begin(), sa.end(), [data, n](Idx a, Idx b) {
        Idx la = n - a;
        Idx lb = n - b;
        Idx lim = std::min(la, lb);
        int c = std::memcmp(data + a, data + b, static_cast<std::size_t>(lim));
        if (c != 0) return c < 0;
        return la < lb;
    });
    return sa;
}

// Length of common prefix between `a[0..a_len]` and `b[0..b_len]`.
Idx matchlen(const std::uint8_t* a, Idx a_len,
             const std::uint8_t* b, Idx b_len) {
    Idx lim = std::min(a_len, b_len);
    Idx i = 0;
    while (i < lim && a[i] == b[i]) ++i;
    return i;
}

// bsdiff binary search: find the suffix in `old` (indexed via SA `I`)
// whose prefix matches `query` longest. Iterative form of the canonical
// recursive `search()` from Colin Percival's bsdiff.c.
Idx search(const std::vector<Idx>& I,
           const std::uint8_t* old_data, Idx old_size,
           const std::uint8_t* query, Idx query_len,
           Idx* pos)
{
    Idx st = 0;
    Idx en = old_size - 1;
    while (en - st >= 2) {
        Idx mid = st + (en - st) / 2;
        Idx olen = old_size - I[static_cast<std::size_t>(mid)];
        Idx lim = std::min(olen, query_len);
        int c = std::memcmp(old_data + I[static_cast<std::size_t>(mid)],
                            query,
                            static_cast<std::size_t>(lim));
        if (c < 0) {
            st = mid;
        } else {
            en = mid;
        }
    }
    Idx pst = I[static_cast<std::size_t>(st)];
    Idx pen = I[static_cast<std::size_t>(en)];
    Idx x = matchlen(old_data + pst, old_size - pst, query, query_len);
    Idx y = matchlen(old_data + pen, old_size - pen, query, query_len);
    if (x > y) { *pos = pst; return x; }
    *pos = pen;
    return y;
}

// ---------------------------------------------------------------------------
// LEB128 varint encoders. The unsigned form matches the integer-encoding
// crate's `VarInt` used by bipatch; the signed form is zigzag-then-uvarint.
// ---------------------------------------------------------------------------
void emit_uvarint(std::vector<std::uint8_t>& out, std::uint64_t v) {
    while (v >= 0x80) {
        out.push_back(static_cast<std::uint8_t>((v & 0x7F) | 0x80));
        v >>= 7;
    }
    out.push_back(static_cast<std::uint8_t>(v));
}

void emit_svarint(std::vector<std::uint8_t>& out, std::int64_t v) {
    std::uint64_t zz = (static_cast<std::uint64_t>(v) << 1)
                     ^ static_cast<std::uint64_t>(v >> 63);
    emit_uvarint(out, zz);
}

// Append one bipatch control entry plus its inline diff/extra bytes.
void emit_loop(std::vector<std::uint8_t>& body,
               const std::uint8_t* new_data, Idx last_scan, Idx lenf,
               const std::uint8_t* old_data, Idx last_pos,
               Idx extra_start, Idx extra_len,
               Idx seek)
{
    emit_uvarint(body, static_cast<std::uint64_t>(lenf));
    for (Idx i = 0; i < lenf; ++i) {
        body.push_back(static_cast<std::uint8_t>(
            new_data[last_scan + i] - old_data[last_pos + i]));
    }
    emit_uvarint(body, static_cast<std::uint64_t>(extra_len));
    body.insert(body.end(),
                new_data + extra_start,
                new_data + extra_start + extra_len);
    emit_svarint(body, seek);
}

std::vector<std::uint8_t> zstd_compress(const std::vector<std::uint8_t>& body) {
    std::size_t bound = ZSTD_compressBound(body.size());
    std::vector<std::uint8_t> out(bound);
    std::size_t got = ZSTD_compress(out.data(), bound,
                                    body.data(), body.size(),
                                    /*level=*/3);
    if (ZSTD_isError(got)) {
        throw std::runtime_error(
            std::string("dashpod::patch::make_patch: zstd compression failed: ")
            + ZSTD_getErrorName(got));
    }
    out.resize(got);
    return out;
}

}  // namespace

std::vector<std::uint8_t> make_patch(std::span<const std::uint8_t> older,
                                     std::span<const std::uint8_t> newer)
{
    const std::uint8_t* old_data = older.data();
    const Idx           old_size = static_cast<Idx>(older.size());
    const std::uint8_t* new_data = newer.data();
    const Idx           new_size = static_cast<Idx>(newer.size());

    std::vector<std::uint8_t> body;
    body.reserve(static_cast<std::size_t>(new_size) + 16);

    // bipatch header: u32_le(0x0000B1DF) u32_le(0x00001000)
    static constexpr std::uint8_t kHeader[8] = {
        0xDF, 0xB1, 0x00, 0x00,
        0x00, 0x10, 0x00, 0x00,
    };
    body.insert(body.end(), std::begin(kHeader), std::end(kHeader));

    if (new_size == 0) {
        // Header-only stream is a valid bipatch (EOF at first AddLen
        // boundary terminates cleanly).
        return zstd_compress(body);
    }

    if (old_size == 0) {
        // No base to diff against — emit `newer` verbatim as one copy span.
        emit_uvarint(body, 0);                                       // add_len
        emit_uvarint(body, static_cast<std::uint64_t>(new_size));    // copy_len
        body.insert(body.end(), new_data, new_data + new_size);
        emit_svarint(body, 0);                                       // seek
        return zstd_compress(body);
    }

    const std::vector<Idx> sa = build_suffix_array(old_data, old_size);

    // bsdiff main loop. Variable names follow Colin Percival's original
    // bsdiff.c so the algorithm is easy to cross-reference.
    Idx scan = 0;
    Idx len = 0;
    Idx pos = 0;
    Idx last_scan = 0;
    Idx last_pos = 0;
    Idx last_offset = 0;

    while (scan < new_size) {
        Idx oldscore = 0;

        // scsc = scan + len at the start of each outer iteration; then
        // we advance scan one byte at a time looking for a "good enough"
        // match.
        for (Idx scsc = (scan += len); scan < new_size; ++scan) {
            len = search(sa,
                         old_data, old_size,
                         new_data + scan, new_size - scan,
                         &pos);

            for (; scsc < scan + len; ++scsc) {
                if (scsc + last_offset < old_size
                    && old_data[scsc + last_offset] == new_data[scsc]) {
                    ++oldscore;
                }
            }

            if ((len == oldscore && len != 0) || (len > oldscore + 8)) {
                break;
            }

            if (scan + last_offset < old_size
                && old_data[scan + last_offset] == new_data[scan]) {
                --oldscore;
            }
        }

        if (len != oldscore || scan == new_size) {
            // Forward extension from (last_scan, last_pos): pick the i
            // that maximises (2*matches − span), to favour denser runs.
            Idx s = 0, Sf = 0, lenf = 0;
            {
                Idx i = 0;
                while (last_scan + i < scan && last_pos + i < old_size) {
                    if (old_data[last_pos + i] == new_data[last_scan + i]) ++s;
                    ++i;
                    if (s * 2 - i > Sf * 2 - lenf) { Sf = s; lenf = i; }
                }
            }

            // Backward extension from (scan, pos), mirror of the above.
            Idx lenb = 0;
            if (scan < new_size) {
                s = 0;
                Idx Sb = 0;
                for (Idx i = 1; i <= scan - last_scan && i <= pos; ++i) {
                    if (old_data[pos - i] == new_data[scan - i]) ++s;
                    if (s * 2 - i > Sb * 2 - lenb) { Sb = s; lenb = i; }
                }
            }

            // Forward and backward windows may overlap. Pick the split
            // that maximises matched bytes overall.
            if (last_scan + lenf > scan - lenb) {
                Idx overlap = (last_scan + lenf) - (scan - lenb);
                s = 0;
                Idx Ss = 0;
                Idx lens = 0;
                for (Idx i = 0; i < overlap; ++i) {
                    if (new_data[last_scan + lenf - overlap + i]
                        == old_data[last_pos + lenf - overlap + i]) ++s;
                    if (new_data[scan - lenb + i]
                        == old_data[pos - lenb + i]) --s;
                    if (s > Ss) { Ss = s; lens = i + 1; }
                }
                lenf += lens - overlap;
                lenb -= lens;
            }

            const Idx extra_start = last_scan + lenf;
            const Idx extra_len   = (scan - lenb) - (last_scan + lenf);
            const Idx seek        = (pos - lenb) - (last_pos + lenf);

            emit_loop(body,
                      new_data, last_scan, lenf,
                      old_data, last_pos,
                      extra_start, extra_len,
                      seek);

            last_scan   = scan - lenb;
            last_pos    = pos - lenb;
            last_offset = pos - scan;
        }
    }

    return zstd_compress(body);
}

}  // namespace dashpod::patch
