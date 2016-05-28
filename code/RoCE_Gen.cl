# input  port 1: RDMA requests from Endpoint
# input  port 2: connection management
# output port 1: network stream
# no signal

.include "nstream.clh"
.include "Infiniband.clh"
.include "Metadata.clh"
.include "IPChecksum.clh"

.element RoCE_Gen <2,1> {
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
        // initialize the states
    }
    .handler {
        if (opcode == OP_CMREP) {
            if (flit_count == 1) {
                Flit1MADHeader f;
                // fill in the fields of the 1st flit
                // some code
                // calculate the ICRC
                // some code
                // and send the flit out
                NetworkStream ns;
                ns.flit.fd.sop      = false;
                ns.flit.fd.eop      = false;
                ns.flit.fd.padbytes = 0;
                ns.flit.fd.data     = f.raw;
                set_output_port(PORT_1, ns.raw);
                return PORT_ALL;
            }
            else if (flit_count == 2) {
                // similar to above				
                // fill in the fields of the 2nd flit
                // calculate the ICRC
                // and send the flit out
            }
            else if (flit_count == 3) {
                // similar to above				
            }
            else if (flit_count <= 8) {
                // similar to above
            }
            else if (flit_count == 9) {
                // similar to above
            }
            else if (flit_count == 10) {
                // similar to above
            }
            ++flit_count;
        }
        else if (opcode == OP_CMREQ) {
            // similar to above
        }
        else if (opcode == OP_CMREQ1) {
            // similar to above
        }
        else if (opcode == OP_CMREQ2) {
            // similar to above
        }
        else if (opcode == OP_CMREJ) {
            // similar to above
        }
        else if (opcode == OP_CMRTU) {
            // similar to above
        }
        else if (opcode == OP_CMREJ) {
            // similar to above
        }
        else if (opcode == OP_CMDREQ) {
            // similar to above
        }
        else if (opcode == OP_CMDREP) {
            // similar to above
        }
        else if (opcode == OP_ACK) {
            // similar to above
        }
        else if (opcode == OP_RDMA_READ_REQUEST) {
            // similar to above
        }
        else if (readcm) {
            // read from RoCE_Connector via PORT_2
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
                    // fill in the fields of the 0th flit
                    // some code
                    ICRC_RESET();
                    // calculate the ICRC
                    // some code
                    // and send the flit out
                    NetworkStream ns;
                    ns.flit.fd.sop      = true;
                    ns.flit.fd.eop      = false;
                    ns.flit.fd.padbytes = 0;
                    ns.flit.fd.data     = f.raw;
                    set_output_port(PORT_1, ns.raw);
                    return PORT_ALL;
                }
                else if (gm.data.opcode == OP_CMRTU) {
                    // similar to above
                }
                else if (gm.data.opcode == OP_CMREJ) {
                    // similar to above
                }
                else if (gm.data.opcode == OP_CMDREQ) {
                    // similar to above
                }
                else if (gm.data.opcode == OP_CMDREP) {
                    // similar to above
                }
            }
        }
        else {
            // read from RoCE_EndPoint via PORT_1
            if (test_input_port(PORT_1)) {
                gm.raw = read_input_port(PORT_1);
                if (gm.data.opcode == OP_SEND_Only) {
                    // similar to above
                }
                else
                    // other cases similar to above
            }
        }
    }
}
