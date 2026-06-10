module D_latch(
	input D,
	input C,
	output Q
);

wire neg_D;
not(neg_D,D);

wire out_and_up; //C & ~D
and(out_and_up,C,neg_D);

wire out_and_down; //C & D
and(out_and_down,C,D);

wire out_or_neg_down; //~out_or_down
wire out_or_up;//out_and_up | out_or_neg_down
or(out_or_up,out_and_up,out_or_neg_down);

wire out_or_neg_up; //~out_or_up
not(out_or_neg_up,out_or_up);

wire out_or_down;//out_and_down | out_or_neg_up
or(out_or_down,out_and_down,out_or_neg_up);

not(out_or_neg_down,out_or_down);

buf(Q,out_or_neg_up);

endmodule

module D_Flip_Flop(
	input D,
	input C,
	output Q
);
wire Q_master_latch;//output master latch
D_latch master(
	.D(D),
	.C(C),
	.Q(Q_master_latch)
);

wire neg_C;//~C
not(neg_C,C);

wire Q_latch_slave;//output Q latch slave
D_latch slave(
	.D(Q_master_latch),
	.C(neg_C),
	.Q(Q_latch_slave)
);

buf(Q,Q_latch_slave);

endmodule