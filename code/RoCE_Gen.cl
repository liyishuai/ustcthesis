# input  port 1: RDMA requests from Endpoint
# input  port 2: connection management
# output port 1: network stream
# no signal

.include "nstream.clh"
.include "Infiniband.clh"
.include "Metadata.clh"
.include "IPChecksum.clh"

# Dear programmer,
# 
#  This source code has not been tested, nor even compiled.
#  There remain many magic numbers. Please read the specifications carefully.
# 
#  Good Luck!
#  Best wishes!
#  Happy coding!
# 
#  by Yishuai Li
#  on Friday May 20, 2016
# 

.element RoCE_Gen <2, 1> {
    .state {
        bool    readcm;
        uint    table[256];
        GenerateMetadata_Aligned gm;
        uint    icrc;
        ulong   icrcx;
        uint    opcode;
        uint    flit_count;
    }
    .init {
        readcm = true;
        ulong poly = 0xedb88320;
        for (ushort i = 0; i < 256; ++i) {
            ulong crc = i;
            .unroll
            for (uchar j = 0; j < 8; ++j)
                crc >>= 1;
                if (crc & 1) {                    
                    crc ^= poly;  //(crc >>= 1) ^= poly;
                }                   
            table[i] = crc;
        }
        icrc = 0xffffffff;
        icrcx = 0;
        opcode = OP_NULL;
        flit_count = 0;
        return PORT_ALL;
    }
    .handler {
#define MASK(x,y)   ((x) >> ((y) * 8)) & 0xFF
#define ICRC(x,y)   icrc = table[(icrc ^ (MASK(x,y))) & 0xFF] ^ (icrc >> 8)
// https://github.com/SoftRoCE/rxe-dev/blob/master/drivers/infiniband/hw/rxe/rxe_icrc.c
#define ICRC_RESET()    icrc = 0xdebb20e3           // magic number
#define ICRC_REVERSE()  icrc = (MASK(icrc,0) << 3) | (MASK(icrc,1) << 2) | (MASK(icrc,2) << 1) | MASK(icrc,0)
#define I1(x)       ICRC(x,0)
#define I2(x)       ICRC(x,1), I1(x)
#define I3(x)       ICRC(x,2), I2(x)
#define I4(x)       ICRC(x,3), I3(x)
#define I5(x)       ICRC(x,4), I4(x)
#define I6(x)       ICRC(x,5), I5(x)
#define I7(x)       ICRC(x,6), I6(x)
#define I8(x)       ICRC(x,7), I7(x)
            //printf("opcode in GEN = %d\n", opcode);

        if (opcode == OP_CMREQ) {
        }
        else if (opcode == OP_CMREQ1) {
        }
        else if (opcode == OP_CMREQ2) {
        }
        else if (opcode == OP_CMREJ) {
        }
        else if (opcode == OP_CMREP) {
            if (flit_count == 1) {
                Flit1MADHeader f;
                f.data.dst_ip_l = gm.data.data.rep.tuple.dst_ip & 0xFFFF;
                f.data.src_port = gm.data.data.rep.tuple.src_port;
                f.data.dst_port = UDP_DST_PORT;
                f.data.length   = CM_UDP_len;
                f.data.cksum    = 0;

                f.data.bth.opcode           = UD_SEND_Only;
                f.data.bth.se_m_padcnt_tver = 0;            // magic number
                f.data.bth.p_key            = 65535;        // magic number
                f.data.bth.resv             = 0;
                f.data.bth.destqp_h         = 0x00;         // magic number
                f.data.bth.destqp_l         = 0x0001;       // magic number
                f.data.bth.ack              = 0;
                f.data.bth.psn_h            = gm.data.data.rep.psn24_resv8 >> 24;
                f.data.bth.psn_l            = (gm.data.data.rep.psn24_resv8 >> 8) & 0xFFFF;

                f.data.deth.data.qkey       = 0x80010000;   // magic number
                f.data.deth.data.resv       = 0;
                f.data.deth.data.srcqp_h    = 0x00;         // magic number
                f.data.deth.data.srcqp_l    = 0x0001;       // magic number

                f.data.baseversion          = 0x01;
                f.data.mgmtclass            = 0x07;

                I2(f.data.dst_ip_l);
                I2(f.data.src_port);
                I2(f.data.dst_port);
                I2(f.data.length);
                I2(0xFFFF);                                 // UDP Checksum

                I1(f.data.bth.opcode);
                I1(f.data.bth.se_m_padcnt_tver);
                I2(f.data.bth.p_key);
                I1(0xFF);   // BTH reserved, not mentioned in spec, but should be 0xFF
                I1(f.data.bth.destqp_h);
                I2(f.data.bth.destqp_l);
                I1(f.data.bth.ack);
                I1(f.data.bth.psn_h);
                I2(f.data.bth.psn_l);

                I4(f.data.deth.data.qkey);
                I1(f.data.deth.data.resv);
                I1(f.data.deth.data.srcqp_h);
                I2(f.data.deth.data.srcqp_l);

                I1(f.data.baseversion);
                I1(f.data.mgmtclass);

                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = false;
                ns.flit.fd.padbytes = 0;
                ns.flit.fd.data     = f.raw;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
            else if (flit_count == 2) {
                Flit2MADHeader f;
                f.data.high.classversion        = 0x02;
                f.data.high.r1_method7          = 0x03;
                f.data.high.status              = 0;
                f.data.high.classspecific       = 0;
                f.data.high.transactionid       = gm.data.data.rep.transactionid;
                f.data.high.attributeid         = ConnectReply;
                f.data.high.reserved            = 0;
                f.data.high.attributemodifier   = 0;

                f.data.low.rep.localcommid      = gm.data.data.rep.localcommid;
                f.data.low.rep.remotecommid     = gm.data.data.rep.remotecommid;
                f.data.low.rep.localqkey_h      = gm.data.data.rep.localqkey >> 16;

                I1(f.data.high.classversion);
                I1(f.data.high.r1_method7);
                I2(f.data.high.status);
                I2(f.data.high.classspecific);
                I8(f.data.high.transactionid);
                I2(f.data.high.attributeid);
                I2(f.data.high.reserved);
                I4(f.data.high.attributemodifier);

                I4(f.data.low.rep.localcommid);
                I4(f.data.low.rep.remotecommid);
                I2(f.data.low.rep.localqkey_h);

                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = false;
                ns.flit.fd.padbytes = 0;
                ns.flit.fd.data     = f.raw;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
            else if (flit_count == 3) {
                Flit3MADHeader f;
                f.rep.localqkey_l   = gm.data.data.rep.localqkey & 0xFFFF;
                f.rep.localqpn      = gm.data.data.rep.localqpn24_resv8;
                f.rep.localeecn     = 0;                    // magic number
                f.rep.startpsn      = gm.data.data.rep.startpsn24_resv8;
                f.rep.responderres  = 0x10;                 // magic number
                f.rep.initdepth     = 0x00;
                f.rep.targetackdelay5_failoverract2_e2eflowctrl1    = 0x79; // magic number
                f.rep.rnrretrycnt3_srq1_resv4   = 0x00;     // magic number
                f.rep.localcaguid   = gm.data.data.rep.localcaguid;

                I2(f.rep.localqkey_l);
                I4(f.rep.localqpn);
                I4(f.rep.localeecn);
                I4(f.rep.startpsn);
                I1(f.rep.responderres);
                I1(f.rep.initdepth);
                I1(f.rep.targetackdelay5_failoverract2_e2eflowctrl1);
                I8(f.rep.localcaguid);

                .unroll
                    for (uchar i = 0; i < 6; ++i) {
                        f.rep.privatedata[i] = 0;
                        I1(f.rep.privatedata[i]);
                    }

                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = false;
                ns.flit.fd.padbytes = 0;
                ns.flit.fd.data     = f.raw;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
            else if (flit_count <= 8) {
                Flit4MADHeader f;
                f.raw.s0 = 0;
                f.raw.s1 = 0;
                f.raw.s2 = 0;
                f.raw.s3 = 0;

                I8(f.raw.s0);
                I8(f.raw.s1);
                I8(f.raw.s2);
                I8(f.raw.s3);

                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = false;
                ns.flit.fd.padbytes = 0;
                ns.flit.fd.data     = f.raw;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
            else if (flit_count == 9) {
                Flit9MADHeader f;
                .unroll
                    for (uchar i = 0; i < 30; ++i) {
                        f.data.privatedata[i] = 0;
                        I1(f.data.privatedata[i]);
                    }
                f.data.icrc_h = ~icrc >> 16;

                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = false;
                ns.flit.fd.padbytes = 0;
                ns.flit.fd.data     = f.raw;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
            else if (flit_count == 10) {
                Flit10MAD f;
                f.icrc_l = ~icrc & 0xFFFF;

                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = true;
                ns.flit.fd.padbytes = 30;
                ns.flit.fd.data     = f.raw;
                opcode = OP_NULL;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
            ++flit_count;
        }
        else if (opcode == OP_CMRTU) {
            if (flit_count == 1) {
                Flit1MADHeader f;
                f.data.dst_ip_l = gm.data.data.rtu.tuple.dst_ip & 0xFFFF;
                f.data.src_port = gm.data.data.rtu.tuple.src_port;
                f.data.dst_port = UDP_DST_PORT;
                f.data.length               = CM_UDP_len;
                f.data.cksum                = 0;

                f.data.bth.opcode           = UD_SEND_Only;
                f.data.bth.se_m_padcnt_tver = 0;            // magic number
                f.data.bth.p_key            = 65535;        // magic number
                f.data.bth.resv             = 0;
                f.data.bth.destqp_h         = 0x00;         // magic number
                f.data.bth.destqp_l         = 0x0001;       // magic number
                f.data.bth.ack              = 0;
                f.data.bth.psn_h            = gm.data.data.rtu.psn24_resv8 >> 24;
                f.data.bth.psn_l            = (gm.data.data.rtu.psn24_resv8 >> 8) & 0xFFFF;

                f.data.deth.data.qkey       = 0x80010000;   // magic number
                f.data.deth.data.resv       = 0;
                f.data.deth.data.srcqp_h    = 0x00;         // magic number
                f.data.deth.data.srcqp_l    = 0x0001;       // magic number

                f.data.baseversion          = 0x01;
                f.data.mgmtclass            = 0x07;

                I2(f.data.dst_ip_l);
                I2(f.data.src_port);
                I2(f.data.dst_port);
                I2(f.data.length);
                I2(0xFFFF);                                 // UDP Checksum

                I1(f.data.bth.opcode);
                I1(f.data.bth.se_m_padcnt_tver);
                I2(f.data.bth.p_key);
                I1(0xFF);   // BTH reserved, not mentioned in spec, but should be 0xFF
                I1(f.data.bth.destqp_h);
                I2(f.data.bth.destqp_l);
                I1(f.data.bth.ack);
                I1(f.data.bth.psn_h);
                I2(f.data.bth.psn_l);

                I4(f.data.deth.data.qkey);
                I1(f.data.deth.data.resv);
                I1(f.data.deth.data.srcqp_h);
                I2(f.data.deth.data.srcqp_l);

                I1(f.data.baseversion);
                I1(f.data.mgmtclass);

                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = false;
                ns.flit.fd.padbytes = 0;
                ns.flit.fd.data     = f.raw;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
            else if (flit_count == 2) {
                Flit2MADHeader f;
                f.data.high.classversion    = 0x02;
                f.data.high.r1_method7      = 0x03;
                f.data.high.status          = 0;
                f.data.high.classspecific   = 0;
                f.data.high.transactionid   = gm.data.data.rtu.transactionid;
                f.data.high.attributeid         = ConnectReply;
                f.data.high.reserved            = 0;
                f.data.high.attributemodifier   = 0;

                f.data.low.rtu.localcommid      = gm.data.data.rtu.localcommid;
                f.data.low.rtu.remotecommid     = gm.data.data.rtu.remotecommid;
                f.data.low.rtu.privatedata[0]   = 0;
                f.data.low.rtu.privatedata[1]   = 0;

                I1(f.data.high.classversion);
                I1(f.data.high.r1_method7);
                I2(f.data.high.status);
                I2(f.data.high.classspecific);
                I8(f.data.high.transactionid);
                I2(f.data.high.attributeid);
                I2(f.data.high.reserved);
                I4(f.data.high.attributemodifier);

                I4(f.data.low.rtu.localcommid);
                I4(f.data.low.rtu.remotecommid);
                I1(f.data.low.rtu.privatedata[0]);
                I1(f.data.low.rtu.privatedata[1]);

                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = false;
                ns.flit.fd.padbytes = 0;
                ns.flit.fd.data     = f.raw;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
            else if (flit_count <= 8) {
                Flit4MADHeader f;
                f.raw.s0 = 0;
                f.raw.s1 = 0;
                f.raw.s2 = 0;
                f.raw.s3 = 0;

                I8(f.raw.s0);
                I8(f.raw.s1);
                I8(f.raw.s2);
                I8(f.raw.s3);

                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = false;
                ns.flit.fd.padbytes = 0;
                ns.flit.fd.data     = f.raw;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
            else if (flit_count == 9) {
                Flit9MADHeader f;
                .unroll
                    for (uchar i = 0; i < 30; ++i) {
                        f.data.privatedata[i] = 0;
                        I1(f.data.privatedata[i]);
                    }
                ICRC_REVERSE();
                f.data.icrc_h = icrc >> 16;

                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = false;
                ns.flit.fd.padbytes = 0;
                ns.flit.fd.data     = f.raw;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
            else if (flit_count == 10) {
                Flit10MAD f;
                f.icrc_l = icrc & 0xFFFF;

                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = true;
                ns.flit.fd.padbytes = 30;
                ns.flit.fd.data     = f.raw;
                opcode = OP_NULL;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
            ++flit_count;
        }
        else if (opcode == OP_CMREJ) {
        }
        else if (opcode == OP_CMDREQ) {
        }
        else if (opcode == OP_CMDREP) {
        }
        else if (opcode == OP_ACK) {
            if (flit_count == 1) {
                Flit1AETH f;
                f.data.dst_ip_l     = gm.data.data.ack.tuple.dst_ip & 0xFFFF;
                f.data.src_port     = gm.data.data.ack.tuple.src_port;
                f.data.dst_port     = UDP_DST_PORT;
                f.data.length       = RC_ACK_UDP_len;
                f.data.cksum        = 0;

                f.data.bth.opcode           = ACKNOWLEDGE;
                f.data.bth.se_m_padcnt_tver = 0x40;     // magic number
                f.data.bth.p_key            = 65535;    // magic number
                f.data.bth.resv             = 0;
                f.data.bth.destqp_h         = 0x00;     // magic number
                f.data.bth.destqp_l         = 0x00d7;   // magic number
                f.data.bth.ack              = 0;
                f.data.bth.psn_h            = gm.data.data.ack.psn24_resv8 >> 24;
                f.data.bth.psn_l            = (gm.data.data.ack.psn24_resv8 >> 8) & 0xFFFF;

                f.data.aeth.data.syndrome   = gm.data.data.ack.syndrome;
                f.data.aeth.data.msn_h      = gm.data.data.ack.msn24_resv8 >> 24;
                f.data.aeth.data.msn_l      = (gm.data.data.ack.msn24_resv8 >> 8) & 0xFFFF;

                I2(f.data.dst_ip_l);
                I2(f.data.src_port);
                I2(f.data.dst_port);
                I2(f.data.length);
                I2(0xFFFF);                             // UDP Checksum

                I1(f.data.bth.opcode);
                I1(f.data.bth.se_m_padcnt_tver);
                I2(f.data.bth.p_key);
                I1(0xFF);   // BTH reserved, not mentioned in spec, but should be 0xFF
                I1(f.data.bth.destqp_h);
                I2(f.data.bth.destqp_l);
                I1(f.data.bth.ack);
                I1(f.data.bth.psn_h);
                I2(f.data.bth.psn_l);

                I1(f.data.aeth.data.syndrome);
                I1(f.data.aeth.data.msn_h);
                I1(f.data.aeth.data.msn_l);

                ICRC_REVERSE();
                f.data.icrc = icrc;

                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = true;
                ns.flit.fd.padbytes = 2;
                ns.flit.fd.data     = f.raw;
                opcode = OP_NULL;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
        }
        else if (opcode == OP_RDMA_READ_REQUEST) {
            if (flit_count == 1) {
                Flit1RDMA f;
                f.data.dst_ip_l     = gm.data.data.rread.tuple.dst_ip & 0xFFFF;
                f.data.src_port     = gm.data.data.rread.tuple.src_port;
                f.data.dst_port     = UDP_DST_PORT;
                f.data.length       = RC_RREAD_IP_len;
                f.data.cksum        = 0;

                f.data.bth.opcode           = RC_READ_REQUEST;
                f.data.bth.se_m_padcnt_tver = 0x40;     // magic number
                f.data.bth.p_key            = 65535;    // magic number
                f.data.bth.resv             = 0;
                f.data.bth.destqp_h         = gm.data.data.rread.destqpn24_resv8 >> 24;
                f.data.bth.destqp_l         = (gm.data.data.rread.destqpn24_resv8 >> 8) & 0xFFFF;
                f.data.bth.ack              = 0;
                f.data.bth.psn_h            = gm.data.data.rread.psn24_resv8 >> 24;
                f.data.bth.psn_l            = (gm.data.data.rread.psn24_resv8 >> 8) & 0xFFFF;

                f.data.va          = gm.data.data.rread.va;
                f.data.remotekey_h = gm.data.data.rread.remotekey >> 16;

                I2(f.data.dst_ip_l);
                I2(f.data.src_port);
                I2(f.data.dst_port);
                I2(f.data.length);
                I2(0xFFFF);                             // UDP Checksum

                I1(f.data.bth.opcode);
                I1(f.data.bth.se_m_padcnt_tver);
                I2(f.data.bth.p_key);
                I1(0xFF);   // BTH reserved, not mentioned in spec, but should be 0xFF
                I1(f.data.bth.destqp_h);
                I2(f.data.bth.destqp_l);
                I1(f.data.bth.ack);
                I1(f.data.bth.psn_h);
                I2(f.data.bth.psn_l);

                I8(f.data.va);
                I2(f.data.remotekey_h);

                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = false;
                ns.flit.fd.padbytes = 0;
                ns.flit.fd.data     = f.raw;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
            else if (flit_count == 2) {
                Flit2RDMA f;
                f.data.remotekey_l  = gm.data.data.rread.remotekey & 0xFFFF;
                f.data.dmalen       = gm.data.data.rread.dmalen;

                I2(f.data.remotekey_l);
                I4(f.data.dmalen);

                .unroll
                    for (uchar i = 0; i < 4; ++i) {
                        f.data.payload[i] = MASK(icrc, i);
                    }

                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = true;
                ns.flit.fd.padbytes = 22;
                ns.flit.fd.data     = f.raw;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
            ++flit_count;
        }
        else if (readcm) {
            if (get_input_port() & PORT_2) {
                gm.raw = read_input_port(PORT_2);
                if (gm.data.opcode == OP_CMREQ1) {
                }
                else if (gm.data.opcode == OP_CMREQ2) {
                }
                else if (gm.data.opcode == OP_CMREP) {
                    opcode = OP_CMREP;
                    flit_count = 1;
                    Flit0Header f;
                    .unroll
                        for (uchar i = 0; i < 6; ++i) {
                            f.data.dst_mac[i] = gm.data.data.rep.tuple.dmac[i];
                            f.data.src_mac[i] = gm.data.data.rep.tuple.smac[i];
                        }
                    f.data.eth_type = InternetProtocol;

                    f.data.ver_len  = IPv4_20Bytes;
                    f.data.tos      = Default_ECT0;
                    f.data.ip_len   = CM_IP_len;
                    f.data.ip_id    = 7680;         // magic number
                    f.data.frag_off = DontFragment_0Bytes;
                    f.data.ttl      = TimeToLive;
                    f.data.protocol = UserDatagramProtocol;
                    f.data.src_ip   = gm.data.data.rep.tuple.src_ip;
                    f.data.dst_ip_h = gm.data.data.rep.tuple.dst_ip >> 16;
                    uint checksum =
                        (f.data.ver_len << 8) + f.data.tos +
                        f.data.ip_len + f.data.ip_id + f.data.frag_off +
                        (f.data.ttl << 8) + f.data.protocol +
                        (f.data.src_ip >> 16) + (f.data.src_ip & 0xFFFF) +
                        f.data.dst_ip_h + (gm.data.data.rep.tuple.dst_ip & 0xFFFF);
                    f.data.checksum  = ~((checksum & 0xFFFF) + (checksum >> 16));

                    ICRC_RESET();
                    I1(f.data.ver_len);
                    I1(0xFF);                       // Type of Service
                    I2(f.data.ip_len);
                    I2(f.data.ip_id);
                    I2(f.data.frag_off);
                    I1(0xFF);                       // Time to Live
                    I1(f.data.protocol);
                    I2(0xFFFF);                     // Header Checksum
                    I4(f.data.src_ip);
                    I2(f.data.dst_ip_h);

                    NetworkStream ns;
                    ns.flit.fd.sop      = true;
                    ns.flit.fd.eop      = false;
                    ns.flit.fd.padbytes = 0;
                    ns.flit.fd.data     = f.raw;
                    set_output_port(PORT_1, ns.raw);
                    return PORT_ALL;
                }
                else if (gm.data.opcode == OP_CMRTU) {
                    opcode = OP_CMRTU;
                    flit_count = 1;
                    Flit0Header f;
                    .unroll
                        for (uchar i = 0; i < 6; ++i) {
                            f.data.dst_mac[i] = gm.data.data.rtu.tuple.dmac[i];
                            f.data.src_mac[i] = gm.data.data.rtu.tuple.smac[i];
                        }
                    f.data.eth_type = InternetProtocol;
                    f.data.ver_len  = IPv4_20Bytes;
                    f.data.tos      = Default_ECT0;
                    f.data.ip_len   = CM_IP_len;
                    f.data.ip_id    = 1024;         // magic number
                    f.data.frag_off = DontFragment_0Bytes;
                    f.data.ttl      = TimeToLive;
                    f.data.protocol = UserDatagramProtocol;
                    f.data.src_ip   = gm.data.data.rtu.tuple.src_ip;
                    f.data.dst_ip_h = gm.data.data.rtu.tuple.dst_ip >> 16;
                    uint checksum =
                        (f.data.ver_len << 8) + f.data.tos +
                        f.data.ip_len + f.data.ip_id + f.data.frag_off +
                        (f.data.ttl << 8) + f.data.protocol +
                        (f.data.src_ip >> 16) + (f.data.src_ip & 0xFFFF) +
                        f.data.dst_ip_h + (gm.data.data.rtu.tuple.dst_ip & 0xFFFF);
                    f.data.checksum  = ~((checksum & 0xFFFF) + (checksum >> 16));

                    ICRC_RESET();
                    I1(f.data.ver_len);
                    I1(0xFF);                       // Type of Service
                    I2(f.data.ip_len);
                    I2(f.data.ip_id);
                    I2(f.data.frag_off);
                    I1(0xFF);                       // Time to Live
                    I1(f.data.protocol);
                    I2(0xFFFF);                     // Header Checksum
                    I4(f.data.src_ip);
                    I2(f.data.dst_ip_h);

                    NetworkStream ns;
                    ns.flit.fd.sop      = true;
                    ns.flit.fd.eop      = false;
                    ns.flit.fd.padbytes = 0;
                    ns.flit.fd.data     = f.raw;
                    set_output_port(PORT_1, ns.raw);
                    return PORT_ALL;
                }
                else if (gm.data.opcode == OP_CMREJ) {
                }
                else if (gm.data.opcode == OP_CMDREQ) {
                }
                else if (gm.data.opcode == OP_CMDREP) {
                }
            }
        }
        else {
            if (test_input_port(PORT_1)) {
                gm.raw = read_input_port(PORT_1);
                if (gm.data.opcode == OP_SEND_Only) {
                }
                else if (gm.data.opcode == OP_SEND_First) {
                }
                else if (gm.data.opcode == OP_SEND_Middle) {
                }
                else if (gm.data.opcode == OP_SEND_Last) {
                }
                else if (gm.data.opcode == OP_RDMA_READ_REQUEST) {
                    opcode = OP_RDMA_READ_REQUEST;
                    flit_count = 1;
                    Flit0Header f;
                    .unroll
                        for (uchar i = 0; i < 6; ++i) {
                            f.data.dst_mac[i] = gm.data.data.rread.tuple.dmac[i];
                            f.data.src_mac[i] = gm.data.data.rread.tuple.smac[i];
                        }
                    f.data.eth_type = InternetProtocol;
                    f.data.ver_len  = IPv4_20Bytes;
                    f.data.tos      = AssuredFwd_NECT;
                    f.data.ip_len   = RC_ACK_IP_len;
                    f.data.ip_id    = 0;            // magic number
                    f.data.frag_off = DontFragment_0Bytes;
                    f.data.ttl      = TimeToLive;
                    f.data.protocol = UserDatagramProtocol;
                    f.data.src_ip   = gm.data.data.rread.tuple.src_ip;
                    f.data.dst_ip_h = gm.data.data.rread.tuple.dst_ip >> 16;
                    uint checksum =
                        (f.data.ver_len << 8) + f.data.tos +
                        f.data.ip_len + f.data.ip_id + f.data.frag_off +
                        (f.data.ttl << 8) + f.data.protocol +
                        (f.data.src_ip >> 16) + (f.data.src_ip & 0xFFFF) +
                        f.data.dst_ip_h + (gm.data.data.rread.tuple.dst_ip & 0xFFFF);
                    f.data.checksum  = ~((checksum & 0xFFFF) + (checksum >> 16));

                    ICRC_RESET();
                    I1(f.data.ver_len);
                    I1(0xFF);                       // Type of Service
                    I2(f.data.ip_len);
                    I2(f.data.ip_id);
                    I2(f.data.frag_off);
                    I1(0xFF);                       // Time to Live
                    I1(f.data.protocol);
                    I2(0xFFFF);                     // Header Checksum
                    I4(f.data.src_ip);
                    I2(f.data.dst_ip_h);

                    NetworkStream ns;
                    ns.flit.fd.sop      = true;
                    ns.flit.fd.eop      = false;
                    ns.flit.fd.padbytes = 0;
                    ns.flit.fd.data     = f.raw;
                    set_output_port(PORT_1, ns.raw);
                    return PORT_ALL;
                }
                else if (gm.data.opcode == OP_RDMA_WRITE_Only) {
                }
                else if (gm.data.opcode == OP_RDMA_WRITE_First) {
                }
                else if (gm.data.opcode == OP_RDMA_WRITE_Middle) {
                }
                else if (gm.data.opcode == OP_RDMA_WRITE_Last) {
                }
                else if (gm.data.opcode == OP_ACK) {
                    opcode = OP_ACK;
                    flit_count = 1;
                    Flit0Header f;
                    .unroll
                        for (uchar i = 0; i < 6; ++i) {
                            f.data.dst_mac[i] = gm.data.data.ack.tuple.dmac[i];
                            f.data.src_mac[i] = gm.data.data.ack.tuple.smac[i];
                        }
                    f.data.eth_type = InternetProtocol;
                    f.data.ver_len  = IPv4_20Bytes;
                    f.data.tos      = AssuredFwd_NECT;
                    f.data.ip_len   = RC_ACK_IP_len;
                    f.data.ip_id    = 0;            // magic number
                    f.data.frag_off = DontFragment_0Bytes;
                    f.data.ttl      = TimeToLive;
                    f.data.protocol = UserDatagramProtocol;
                    f.data.src_ip   = gm.data.data.ack.tuple.src_ip;
                    f.data.dst_ip_h = gm.data.data.ack.tuple.dst_ip >> 16;
                    uint checksum =
                        (f.data.ver_len << 8) + f.data.tos +
                        f.data.ip_len + f.data.ip_id + f.data.frag_off +
                        (f.data.ttl << 8) + f.data.protocol +
                        (f.data.src_ip >> 16) + (f.data.src_ip & 0xFFFF) +
                        f.data.dst_ip_h + (gm.data.data.ack.tuple.dst_ip & 0xFFFF);
                    f.data.checksum  = ~((checksum & 0xFFFF) + (checksum >> 16));

                    ICRC_RESET();
                    I1(f.data.ver_len);
                    I1(0xFF);                       // Type of Service
                    I2(f.data.ip_len);
                    I2(f.data.ip_id);
                    I2(f.data.frag_off);
                    I1(0xFF);                       // Time to Live
                    I1(f.data.protocol);
                    I2(0xFFFF);                     // Header Checksum
                    I4(f.data.src_ip);
                    I2(f.data.dst_ip_h);

                    NetworkStream ns;
                    ns.flit.fd.sop      = true;
                    ns.flit.fd.eop      = false;
                    ns.flit.fd.padbytes = 0;
                    ns.flit.fd.data     = f.raw;
                    set_output_port(PORT_1, ns.raw);
                    return PORT_ALL;
                }
            }
        }
    }
}
