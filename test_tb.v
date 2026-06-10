`timescale 1ns/1ps

module tb_cacheController;

reg enable;
reg cpu_request;
reg write_request;
reg read_request;
reg clk;
reg reset;
reg [31:0] data;

cacheController dut (
    .enable(enable),
    .cpu_request(cpu_request),
    .write_request(write_request),
    .read_request(read_request),
    .clk(clk),
    .reset(reset),
    .data(data)
);

// Clock 10ns
initial clk = 0;
always #5 clk = ~clk;

task show_state;
    $display("t=%0t | reset=%b cpu=%b rd=%b wr=%b | state=%b (%s)",
        $time, reset, cpu_request, read_request, write_request,
        dut.out_reg_current_state,
        dut.out_reg_current_state == 3'b000 ? "IDLE" :
        dut.out_reg_current_state == 3'b001 ? "COMPARE" :
        dut.out_reg_current_state == 3'b010 ? "READ_HIT" :
        dut.out_reg_current_state == 3'b011 ? "READ_MISS" :
        dut.out_reg_current_state == 3'b100 ? "WRITE_HIT" :
        dut.out_reg_current_state == 3'b101 ? "WRITE_MISS" :
        dut.out_reg_current_state == 3'b110 ? "EVICT" : "UNKNOWN"
    );
endtask

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_cacheController);

    // Initializare
    enable = 1; cpu_request = 0;
    write_request = 0; read_request = 0;
    data = 32'h0; reset = 1;
    #30; // 3 clockuri cu reset activ
    show_state; // expect IDLE

    reset = 0;
    #10;
    show_state; // expect IDLE

    // Test 1 - READ request => trebuie sa mearga in COMPARE
    data = 32'hA5B6C7D8;
    cpu_request = 1;
    read_request = 1;
    #10;
    show_state; // expect COMPARE

    #10;
    show_state; // ramanem in COMPARE

    // Oprim request
    cpu_request = 0;
    read_request = 0;
    #10;
    show_state;

    // Test 2 - WRITE request => trebuie sa mearga in COMPARE
    reset = 1;
    #20;
    reset = 0;
    #10;
    show_state; // expect IDLE

    data = 32'h12345678;
    cpu_request = 1;
    write_request = 1;
    #10;
    show_state; // expect COMPARE

    #10;
    show_state; // ramanem in COMPARE

    cpu_request = 0;
    write_request = 0;
    #10;
    show_state;

    // Test 3 - Reset in mijlocul operatiei
    cpu_request = 1;
    read_request = 1;
    data = 32'hDEADBEEF;
    #10;
    show_state; // expect COMPARE
    reset = 1;
    #20;
    show_state; // expect IDLE
    reset = 0;
    #10;
    show_state; // expect IDLE

    #20;
    $finish;
end

endmodule