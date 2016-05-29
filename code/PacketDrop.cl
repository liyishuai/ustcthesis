.include "nstream.clh"
.import  "Rand.cl"

.element PacketDrop <2,1> {
    .state {
        uchar prob;
        bool packet;
    }
    .init {
        prob = 1;
        packet = false;
        return PORT_ALL;
    }
    .handler {
        if (test_input_port(PORT_1)) {
            NetworkStream ns;
            ns.raw = read_input_port(PORT_1);
            if (ns.flit.fd.sop) {
                packet = true;
                if (test_input_port(PORT_2)) {
                    _Rand_ulong8 rand;
                    rand.raw = read_input_port(PORT_2);
                    if (rand.data[0] < prob)
                        packet = false;
                }
            }
            if (packet)
                set_output_port(PORT_1, ns.raw);
            if (ns.flit.fd.eop)
                packet = false;
        }
        return PORT_ALL;
    }
    .signal {
        ClSignal *sig = (ClSignal *) &event;
        prob = sig->Sig.SParam;
    }
}

.element_group RandomDrop <1,1> {
    Rand :: random(0,1,1)
    PacketDrop :: packetDrop @

    begin      -> [1]packetDrop
    random     -> [2]packetDrop
    packetDrop -> end
}
