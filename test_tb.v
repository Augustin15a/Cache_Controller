`timescale 1ns / 1ps

module cacheController_tb;

    // --- Semnale de intrare (Regs) ---
    reg cpu_request;
    reg write_request;
    reg read_request;
    reg clk;
    reg reset;
    reg [31:0] address;
    
    reg [19*4 - 1:0] tags_from_cache;
    reg tags_delivered;
    reg block_delivered;
    reg [511:0] block_data;
    reg newBlock_delivered;
    reg block_delivered_ram;
    reg [511:0] block_data_ram;
    reg write_done_cache;
    reg [31:0] data_for_cpu_write;
    reg [1:0] lru_way;
    reg victim_dirty;
    reg [18:0] victim_tag;

    // --- Semnale de ieșire (Wires) ---
    wire request_memory_tags;
    wire [6:0] index;
    wire request_block;
    wire [1:0] way_out;
    wire [31:0] data_for_cpu;
    wire data_ready;
    wire send_block_from_ram;
    wire [511:0] block_data_ram_to_cache;
    wire [18:0] tag_to_cache;
    wire [6:0] index_to_cache;
    wire [1:0] way_to_cache;
    wire [31:0] memory_address_to_ram;
    wire request_block_ram;
    wire write_hit_semnal_cache;
    wire [31:0] data_cache;
    wire dirty_bit;
    wire [3:0] word_offset;
    wire write_done_cpu;
    wire request_write_ram;

    // --- Instanțierea UUT (Unit Under Test) ---
    cacheController uut (
        .cpu_request(cpu_request),
        .write_request(write_request),
        .read_request(read_request),
        .clk(clk),
        .reset(reset),
        .address(address),
        .tags_from_cache(tags_from_cache),
        .tags_delivered(tags_delivered),
        .request_memory_tags(request_memory_tags),
        .index(index),
        .block_delivered(block_delivered),
        .block_data(block_data),
        .request_block(request_block),
        .way_out(way_out),
        .data_for_cpu(data_for_cpu),
        .data_ready(data_ready),
        .newBlock_delivered(newBlock_delivered),
        .send_block_from_ram(send_block_from_ram),
        .block_data_ram_to_cache(block_data_ram_to_cache),
        .tag_to_cache(tag_to_cache),
        .index_to_cache(index_to_cache),
        .way_to_cache(way_to_cache),
        .block_delivered_ram(block_delivered_ram),
        .block_data_ram(block_data_ram),
        .memory_address_to_ram(memory_address_to_ram),
        .request_block_ram(request_block_ram),
        .write_done_cache(write_done_cache),
        .write_hit_semnal_cache(write_hit_semnal_cache),
        .data_cache(data_cache),
        .dirty_bit(dirty_bit),
        .word_offset(word_offset),
        .data_for_cpu_write(data_for_cpu_write),
        .write_done_cpu(write_done_cpu),
        .lru_way(lru_way),
        .victim_dirty(victim_dirty),
        .victim_tag(victim_tag),
        .request_write_ram(request_write_ram)
    );

    // --- Generare Ceas (Perioadă de 10ns) ---
    always begin
        #5 clk = ~clk;
    end

    // --- Blocul de Stimuli ---
    initial begin
        // 1. INIȚIALIZARE STRICTĂ (Eliminăm orice valoare de 'X')
        clk = 0;
        reset = 1;
        cpu_request = 0;
        write_request = 0;
        read_request = 0;
        address = 32'b0;
        tags_from_cache = {19'b0, 19'b0, 19'b0, 19'b0};
        tags_delivered = 0;
        block_delivered = 0;
        block_data = 512'b0;
        newBlock_delivered = 0;
        block_delivered_ram = 0;
        block_data_ram = 512'b0;
        write_done_cache = 0;
        data_for_cpu_write = 32'b0;
        lru_way = 2'b00;
        victim_dirty = 0;
        victim_tag = 19'b0;

        // Așteptăm 2 ciclii de ceas complet în starea de Reset
        #20;
        
        // 2. SCOATERE DIN RESET (Pe frontul căzător al ceasului ca să evităm hazardul)
        @(negedge clk);
        reset = 0;
        #10;

        // 3. SCENARIU: CERERE DE CITIRE (READ REQUEST) de la CPU
        @(negedge clk);
        cpu_request = 1;
        read_request = 1;
        address = 32'h00002048; // Adresa din log-ul tău

        // FSM ar trebui să treacă în COMPARE_TAG în următorul ciclu
        @(negedge clk);
        // Oprim cererea de la CPU dacă controller-ul a preluat adresa în registru
        cpu_request = 0; 
        
        // Simulăm că tag-urile sunt aduse din Cache Array
        // Presupunem un TAG diferit ca să forțăm un READ MISS (ex: toate tag-urile din cache sunt 0)
        tags_from_cache = {19'd0, 19'd0, 19'd0, 19'd0}; 
        tags_delivered = 1;

        // În acest moment, FSM vede că e MISS și verifică dacă block-ul vechi e Dirty
        // Lăsăm victim_dirty = 0, deci ar trebui să sară direct în starea READ MISS (011)
        @(negedge clk);
        tags_delivered = 0; // Resetăm semnalul de sincronizare cache

        // Suntem în READ MISS. Așteptăm ca memoria RAM să răspundă cu blocul de date
        #30; 
        
        @(negedge clk);
        block_delivered_ram = 1;
        block_data_ram = {16{32'hAABBCCDD}}; // Umplem blocul cu o valoare test

        // Cache-ul intern confirmă scrierea noului bloc adus din RAM
        @(negedge clk);
        block_delivered_ram = 0;
        newBlock_delivered = 1;

        // FSM ar trebui să se întoarcă în IDLE
        @(negedge clk);
        newBlock_delivered = 0;

        // Lăsăm simularea să ruleze puțin înainte de final
        #50;
        $stop;
    end

    // --- Monitorizare în consolă ---
    initial begin
        $monitor("[CLK %0d] STATE=%b | REQ_TAGS=%b TAGS_DEL=%b REQ_BLK_RAM=%b REQ_BLK=%b DATA_READY=%b | addr=%h", 
                 $time/10, uut.out_reg_current_state, request_memory_tags, tags_delivered, request_block_ram, request_block, data_ready, address);
    end

endmodule