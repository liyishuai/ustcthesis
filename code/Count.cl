.element Count <1,1> {
	.state {
		ulong count;
	}
	.init {
		count = 0;
		return PORT_1;
	}
	.handler {
		if (test_input_port(PORT_1)) {
			flit x = read_input_port(PORT_1);
			if (x.fd.sop)
				++count;
			set_port_output(PORT_1, x);
		}
		return PORT_1;
	}
	.signal {
		ClSignal p;
		p.Sig.LParam[0] = count;
		set_signal(p);
		return last_rport;
	}
}
