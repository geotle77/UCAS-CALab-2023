`include "BUS_LEN.vh"
module transfer_bridge(
    input wire                      clk    ,
    input wire                      resetn ,
 
    // ar 
    output wire    [ 3:0]           arid   , // master -> slave
    output wire    [31:0]           araddr , // master -> slave
    output wire    [ 7:0]           arlen  , // master -> slave, 8'b0
    output wire    [ 2:0]           arsize , // master -> slave
    output wire    [ 1:0]           arburst, // master -> slave, 2'b1
    output wire    [ 1:0]           arlock , // master -> slave, 2'b0
    output wire    [ 3:0]           arcache, // master -> slave, 4'b0
    output wire    [ 2:0]           arprot , // master -> slave, 3'b0
    output wire                     arvalid, // master -> slave
    input  wire                     arready, // slave  -> master

    // r            
    input  wire    [ 3:0]           rid   , // slave  -> master
    input  wire    [31:0]           rdata , // slave  -> master
    input  wire    [ 1:0]           rresp , // slave  -> master, ignore
    input  wire                     rlast , // slave  -> master, ignore
    input  wire                     rvalid, // slave  -> master
    output wire                     rready, // master -> slave

    // aw           
    output wire    [ 3:0]           awid   , // master -> slave, 4'b1
    output wire    [31:0]           awaddr , // master -> slave
    output wire    [ 7:0]           awlen  , // master -> slave, 8'b0
    output wire    [ 2:0]           awsize , // master -> slave
    output wire    [ 1:0]           awburst, // master -> slave, 2'b1
    output wire    [ 1:0]           awlock , // master -> slave, 2'b0
    output wire    [ 3:0]           awcache, // master -> slave, 4'b0
    output wire    [ 2:0]           awprot , // master -> slave, 3'b0
    output wire                     awvalid, // master -> slave
    input  wire                     awready, // slave  -> master

    // w
    output wire    [ 3:0]           wid   , // master -> slave, 4'b1
    output wire    [31:0]           wdata , // master -> slave
    output wire    [ 3:0]           wstrb , // master -> slave
    output wire                     wlast , // master -> slave, 1'b1
    output wire                     wvalid, // master -> slave
    input  wire                     wready, // slave  -> master

    // b
    input  wire   [ 3:0]            bid   , // slave  -> master, ignore
    input  wire   [ 1:0]            bresp , // slave  -> master, ignore
    input  wire                     bvalid, // slave  -> master
    output wire                     bready, // master -> slave

    // icache interface
    input  wire         	         icache_rd_req,
    input  wire[ 2:0]               icache_rd_type,
    input  wire[31:0]               icache_rd_addr,
    output wire         	         icache_rd_rdy,			// icache_addr_ok
    output wire         	         icache_ret_valid,	// icache_data_ok
	output wire			             icache_ret_last,
    output wire[31:0]               icache_ret_data,
    
    // data sram interface
    input  wire                     data_sram_en     ,
    input  wire                     data_sram_wr     ,
    input  wire   [ 3:0]            data_sram_wstrb  ,
    input  wire   [ 1:0]            data_sram_size   , 
    input  wire   [31:0]            data_sram_addr   ,
    input  wire   [31:0]            data_sram_wdata  ,
    output wire   [31:0]            data_sram_rdata  ,
    output wire                     data_sram_addr_ok,
    output wire                     data_sram_data_ok


);

    wire reset;
    assign reset = ~resetn;

    // ar
    reg  [3:0] arid_reg;
    reg [31:0] araddr_reg;
    reg  [2:0] arsize_reg;
    reg        arvalid_reg;
    reg [7:0]  arlen_reg;
    reg [1:0]  arburst_reg;
    reg [1:0]  arlock_reg;
    reg [3:0]  arcache_reg;
    reg [2:0]  arprot_reg;
    assign arid = arid_reg;
    assign araddr = araddr_reg;
    assign arsize = arsize_reg;
    assign arvalid = arvalid_reg;
    assign arlen = arlen_reg;
    assign arburst = arburst_reg;
    assign arlock   = arlock_reg;
    assign arcache  =  arcache_reg;
    assign arprot   =  arprot_reg;
    // assign arlen    = 8'b0;
    // assign arburst  = 2'b1;
    // assign arlock   = 2'b0;
    // assign arcache  = 4'b0;
    // assign arprot   = 3'b0;

    // r
    assign rready = rdata_curr_state[1] || rdata_curr_state[2];//r_business_cnt_inst != 1'b0 || r_business_cnt_data != 1'b0;

    // aw
    reg [31:0] awaddr_reg;
    reg [2:0]  awsize_reg;
    reg        awvalid_reg;
    assign awaddr = awaddr_reg;
    assign awsize = awsize_reg;
    assign awvalid = awvalid_reg;
    assign awid     = 4'b1;
    assign awlen    = 8'b0;
    assign awburst  = 2'b1;
    assign awlock   = 2'b0;
    assign awcache  = 4'b0;
    assign awprot   = 3'b0;

    // w
    reg [31:0] wdata_reg;
    reg [3:0]  wstrb_reg;
    reg        wvalid_reg;
    assign wdata = wdata_reg;
    assign wstrb = wstrb_reg;
    assign wvalid = wvalid_reg;
    assign wid      = 4'b1;
    assign wlast    = 1'b1;

    //b
    reg bready_reg;
    assign bready = bready_reg;

    // state machine

    parameter READ_REQ_RST          = 5'b00001; // 1
    parameter READ_DATA_REQ_START   = 5'b00010; // 2
    parameter READ_INST_REQ_START   = 5'b00100; // 4
    parameter READ_DATA_REQ_CHECK   = 5'b01000; // 8
    parameter READ_REQ_END          = 5'b10000; // 16

    parameter READ_DATA_RST         = 4'b0001; // 1
    parameter READ_DATA_START       = 4'b0010; // 2
    parameter READ_DATA_MID         = 4'b0100; // 4
    parameter READ_DATA_END         = 4'b1000; // 8

    parameter WRITE_RST             = 3'b001; // 1
    parameter WRITE_START           = 3'b010; // 2
    parameter WRITE_END             = 3'b100; // 8

    parameter WRITE_RSP_RST         = 3'b001; // 1
    parameter WRITE_RSP_START       = 3'b010; // 2
    parameter WRITE_RSP_END         = 3'b100; // 8

    reg  [ 4:0] rreq_curr_state;
    reg  [ 4:0] rreq_next_state;
    reg  [ 3:0] rdata_curr_state;
    reg  [ 3:0] rdata_next_state;
    reg  [ 3:0] wrd_curr_state;
    reg  [ 3:0] wrd_next_state;
    reg  [ 2:0] wrsp_curr_state;
    reg  [ 2:0] wrsp_next_state;

    reg r_business_cnt_inst;
    reg r_business_cnt_data;
    
    
    
    //--------------------the 1st segment of state machine--------------------


    always @(posedge clk) begin
        if(reset) begin
            rreq_curr_state <= READ_REQ_RST;
            rdata_curr_state <= READ_DATA_RST;
            wrd_curr_state <= WRITE_RST;
            wrsp_curr_state <= WRITE_RSP_RST;
        end    
        else begin
            rreq_curr_state <= rreq_next_state;
            rdata_curr_state <= rdata_next_state;
            wrd_curr_state <= wrd_next_state;
            wrsp_curr_state <= wrsp_next_state;
        end 
    end
    
    
    
    
    
    //--------------------the 2nd segment of state machine--------------------



    //----------read request----------
    
    always @(*) begin
        case(rreq_curr_state)
            READ_REQ_RST: begin
                if(data_sram_en & ~data_sram_wr)
                    rreq_next_state = READ_DATA_REQ_CHECK;
                else if(icache_rd_req)
                    rreq_next_state = READ_INST_REQ_START;
                else
                    rreq_next_state = rreq_curr_state;
            end
            
            READ_DATA_REQ_CHECK: begin
                if(block)
                    rreq_next_state = rreq_curr_state;
                else
                    rreq_next_state = READ_DATA_REQ_START;
            end
            
            READ_DATA_REQ_START, READ_INST_REQ_START: begin
                if(arvalid & arready)
                    rreq_next_state = READ_REQ_END;
                else
                    rreq_next_state = rreq_curr_state;
            end

            READ_REQ_END: begin
                if(rdata_curr_state[3])begin
                    rreq_next_state = READ_REQ_RST;
                end
                else begin
                    rreq_next_state = READ_REQ_END;
                end
            end
            default:
                rreq_next_state = READ_REQ_RST;
        endcase
    end



    //----------read data (response)----------

    always @(*) begin
        case(rdata_curr_state)
            READ_DATA_RST: begin
                if((arready && arvalid) || r_business_cnt_inst != 1'b0 || r_business_cnt_data != 1'b0)
                    rdata_next_state = READ_DATA_START;
                else 
                    rdata_next_state = rdata_curr_state;
            end

            READ_DATA_START: begin
                if(rvalid && rready && rlast)
                    rdata_next_state = READ_DATA_END;
                else if(rvalid && rready)
                    rdata_next_state = READ_DATA_MID;
                else
                    rdata_next_state = rdata_curr_state;
                
            end

            READ_DATA_MID:begin
                if(rvalid && rready && rlast)
                    rdata_next_state = READ_DATA_END;
                else if(rvalid && rready)
                    rdata_next_state = rdata_curr_state;
                else
                    rdata_next_state = READ_DATA_START;
            end

            READ_DATA_END: begin
                if((arready && arvalid) || r_business_cnt_inst != 1'b0 || r_business_cnt_data != 1'b0)
                    rdata_next_state = READ_DATA_START;
                else
                    rdata_next_state = READ_DATA_RST;
            end

            default:
                rdata_next_state = READ_DATA_RST;
        endcase
        
    end
    
    
    
    //----------write request & write data----------

    always @(*) begin
        case(wrd_curr_state)
            WRITE_RST: begin
                if(data_sram_en && data_sram_wr) 
                    wrd_next_state = WRITE_START;
                else 
                    wrd_next_state = wrd_curr_state;
            end

            WRITE_START: begin
                if(wvalid & wready)
                    wrd_next_state = WRITE_END;
                else
                    wrd_next_state = wrd_curr_state;
            end

            WRITE_END: begin
                wrd_next_state = WRITE_RST;   
            end
            
            default:
                wrd_next_state = WRITE_RST;
        endcase
    end
    
    
    
    //----------write response----------

    always @(*) begin
        case(wrsp_curr_state)
            WRITE_RSP_RST: begin
                if(wvalid & wready) 
                    wrsp_next_state = WRITE_RSP_START;
                else
                    wrsp_next_state = wrsp_curr_state;
            end

            WRITE_RSP_START: begin
                if(bvalid & bready)
                    wrsp_next_state = WRITE_RSP_END;
                else
                    wrsp_next_state = wrsp_curr_state;
            end

            WRITE_RSP_END: begin
                if(bvalid & bready)
                    wrsp_next_state = wrsp_curr_state;
                else
                    wrsp_next_state = WRITE_RSP_RST;
            end

            default:
                wrsp_next_state = WRITE_RSP_RST;
        endcase
    end
    
    
    
    
    
    //--------------------the 3rd segment of state machine--------------------
    
    
    
    // ar
    always @(posedge clk) begin
        if(reset) begin
            arid_reg <= 4'b0;
            araddr_reg <= 32'b0;
            arsize_reg <= 3'b010;
            {arlen_reg,arburst_reg, arlock_reg, arcache_reg, arprot_reg} <= {8'b0,2'b01, 2'b0, 4'b0, 1'b0};
        end 
        else if(rreq_next_state == READ_DATA_REQ_START || rreq_curr_state == READ_DATA_REQ_START) begin
            arid_reg <= 4'b1;
            araddr_reg <= data_sram_addr;
            arsize_reg <= {1'b0, data_sram_size};
            arlen_reg <= 8'b0;
        end 
        else if(rreq_next_state == READ_INST_REQ_START || rreq_curr_state == READ_INST_REQ_START) begin
            arid_reg <= 4'b0;
            araddr_reg <= icache_rd_addr;
            //arsize_reg <= {2{icache_rd_type[2]}};//{1'b0, inst_sram_size};
            arlen_reg <= 8'b00000011;
            arburst_reg <= 2'b01;
        end 
        /*else begin
            arid_reg <= 4'b0;
            araddr_reg <= 32'b0;
            arsize_reg <= 3'b0;
        end*/
    end

    always @(posedge clk) begin
        if(reset | arready)
            arvalid_reg <= 1'b0;
        else if(rreq_curr_state == READ_DATA_REQ_START || rreq_curr_state == READ_INST_REQ_START)
            arvalid_reg <= 1'b1;  
    end

    reg [3:0] rid_reg;
    always @(posedge clk) begin
        if(reset || rdata_next_state == READ_DATA_RST) 
            rid_reg <= 4'b0;
        else if(rvalid) 
            rid_reg <= rid;
       
    end

    //aw
    always @(posedge clk) begin
        if(reset) begin
            awaddr_reg <= 32'b0;
            awsize_reg <= 3'b0;
        end 
        else if(wrd_curr_state == WRITE_START || wrd_next_state == WRITE_START) begin
            awaddr_reg <= data_sram_addr;
            awsize_reg <= {1'b0, data_sram_size};
        end 
        else begin
            awaddr_reg <= 32'b0;
            awsize_reg <= 3'b0;
        end
    end
    
    // my
    reg [31:0] awaddr_block;
    always @(posedge clk) begin
        if(reset)
            awaddr_block <= 32'b0;
        else if(awaddr != 32'b0)
            awaddr_block <= awaddr;
        else if(bvalid & bready)
            awaddr_block <= 32'b0;
    end
    wire block;
    assign block = data_sram_addr == awaddr_block && araddr != 32'b0;

            
            
    
    reg write_pending;
    always @(posedge clk) begin
        if(reset | awready | write_pending)
            awvalid_reg <= 1'b0;
        else if(wrd_curr_state == WRITE_START)
            awvalid_reg <= 1'b1;
    end

    always @(posedge clk) begin
        if(reset) 
            write_pending <= 1'b0;
        else if(awvalid && awready)
            write_pending <= 1'b1;
        else if(wrd_next_state == WRITE_END)
            write_pending <= 1'b0;
    end
    
    //w
    always @(posedge clk) begin
        if(reset) begin
            wdata_reg <= 32'b0;
            wstrb_reg <= 4'b0;
        end 
        else if(wrd_curr_state == WRITE_START || wrd_next_state == WRITE_START) begin
            wdata_reg <= data_sram_wdata;
            wstrb_reg <= data_sram_wstrb;
        end 
    end

    always @(posedge clk) begin
        if(reset | wready)
            wvalid_reg <= 1'b0;
        else if(wrd_curr_state == WRITE_START) 
            wvalid_reg <= 1'b1;
        else 
            wvalid_reg <= 1'b0;
    end
    
    // b
    always @(posedge clk) begin
        if(reset | bvalid) 
            bready_reg <= 1'b0;
        else if(wrsp_next_state == WRITE_RSP_START)
            bready_reg <= 1'b1;
        else 
            bready_reg <= 1'b0;
    end
    


    always @(posedge clk) begin
        if(reset) begin
            r_business_cnt_inst <= 1'b0;
            r_business_cnt_data <= 1'b0;
        end
        else if(arready & arvalid & rvalid & rready &rlast) begin
            if(~arid[0] && ~rid[0])
                r_business_cnt_inst <= r_business_cnt_inst;
            if(arid[0] && rid[0])
                r_business_cnt_data <= r_business_cnt_data;
            if(~arid[0] && rid[0]) begin
                r_business_cnt_inst <= r_business_cnt_inst + 2'b1;
                r_business_cnt_data <= r_business_cnt_data - 2'b1;
            end 
            if(arid[0] && ~rid[0]) begin
                r_business_cnt_inst <= r_business_cnt_inst - 2'b1;
                r_business_cnt_data <= r_business_cnt_data + 2'b1;
            end
        end
        else if(arready & arvalid) begin
            if(~arid[0])
                r_business_cnt_inst <= r_business_cnt_inst + 2'b1;
            if(arid[0])
                r_business_cnt_data <= r_business_cnt_data + 2'b1;
        end
        else if (rvalid & rready & rlast) begin
            if(~rid[0])
                r_business_cnt_inst <= r_business_cnt_inst - 2'b1;
            if(rid[0])
                r_business_cnt_data <= r_business_cnt_data - 2'b1;
        end
    end


    

    //assign inst_sram_addr_ok = rreq_curr_state == READ_REQ_END && ~arid[0];
    //assign inst_sram_data_ok = rdata_curr_state == READ_DATA_END && ~rid_reg[0];
    assign icache_rd_rdy = rreq_curr_state == READ_REQ_END && ~arid[0];
    assign icache_ret_valid = (|rdata_curr_state[3:2]) && ~rid_reg[0];
    assign icache_ret_last = rdata_curr_state[3] && ~rid_reg[0];
    assign data_sram_addr_ok = arid[0] & arvalid & arready | wid[0] & awvalid & awready ; //read or write
    assign data_sram_data_ok = ((|rdata_curr_state[3:2]) && rid_reg[0]) || (wrsp_curr_state == WRITE_RSP_END); //read or write

    reg [31:0] inst_sram_buf;
    reg [31:0] data_sram_buf;
    
    always @(posedge clk) begin
        if(reset) 
            inst_sram_buf <= 32'b0;
        else if(rvalid && rready && ~rid[0]) 
            inst_sram_buf <= rdata;
    end

    always @(posedge clk) begin 
        if(reset) 
            data_sram_buf <= 32'b0;
        else if(rvalid && rready && rid[0]) 
            data_sram_buf <= rdata;
    end

    assign icache_ret_data = inst_sram_buf;
    assign data_sram_rdata = data_sram_buf;


endmodule