#ifndef DASHPOD_EXPORT_H
#define DASHPOD_EXPORT_H

#ifdef _WIN32
  #ifdef DASHPOD_BUILDING
    #define DASHPOD_EXPORT __declspec(dllexport)
  #else
    #define DASHPOD_EXPORT __declspec(dllimport)
  #endif
#else
  #define DASHPOD_EXPORT __attribute__((visibility("default")))
#endif

#endif
