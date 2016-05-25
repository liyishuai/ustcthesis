typedef struct __attribute__((packed)) {
    struct __attribute__((packed)) flit_data {
        bool   sop;
        bool   eop;
        uchar  padbytes;
        ulong4 data;
    } fd;
    uchar resv[sizeof(ulong8) - sizeof(struct flit_data)];
} flit;

