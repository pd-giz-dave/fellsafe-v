module contours

// contours - Find contours of 4-connected components.
//    This module is a re-implementation of blob.h from https://github.com/BlockoS/blob
//    Which is a C implementation of:
//        "A linear-time component-labeling algorithm using contour tracing technique"
//        by Fu Chang, Chun-Jen Chen, and Chi-Jen Lu.
//    It has been tweaked to reduce the connectivity searched from 8 to 4 (i.e. direct neighbours only).
//    It is also extended to compute the area of the components found and various other properties.
//    Blame the original for any weird looking logic in here!
