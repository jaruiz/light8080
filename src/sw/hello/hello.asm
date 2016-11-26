;*******************************************************************************
; hello.asm -- light8080 core basic demo: 'Hello World!"
;*******************************************************************************
; Should be used with MCU wrapper vhdl\mcu\mcu80.vhdl
; Assembler format compatible with ASL on Linux.
;*******************************************************************************
; This program will print a Hello message to the MCU UART, then will loop 
; forever copying the input port P1 to the output port P2 doing some arith to
; convince you the CPU is alive:
;   P2 = P1 | (P1 << 2) 
; This demo is meant to be used as a starting point for those crowds anxiously 
; wanting to play with the mcu80 core -- which in turn is little more than an 
; usage example for the light8080 cpu core.
;*******************************************************************************

          .area CODE0 (ABS,CON)
          .org 0H0
          
          MASK_RX_IRQ =   0H20
          MASK_TX_IRQ =   0H10
          MASK_RX_RDY =   0H02
          MASK_TX_RDY =   0H01

          UART_DATA =     0H80
          UART_STATUS =   0H81
          UART_BAUDL =    0H82
          UART_BAUDH =    0H83
          IRQ_ENABLE =    0H88
          P1IN =          0H84
          P2OUT =         0H86


;*******************************************************************************

          
          jmp   start           ; Skip the rst address area
                        
        ;***** Interrupt vectors in area 0008h-0038h *****************
        
          .org  0h08            ; interrupt vector 1
          ret
          .org  0h10            ; interrupt vector 2
          ret
          .org  0h18            ; interrupt vector 3
          ret
          .org  0h20            ; interrupt vector 4
          ret
          .org  0h28            ; interrupt vector 5
          ret
          .org  0h30            ; interrupt vector 6
          ret
          
          .org  0h38            ; interrupt vector 7
int38h:   jmp   irq_uart        ; UART interrupt 

       
          ;***** program entry point *******************************************
                

          .org 0H60
start:    lxi   sp,stack

          ; Initialize UART RX and TX buffers
          lxi   h,void_buffer
          shld  ptr_tx
          lxi   h,rx_buffer
          shld  ptr_rx
          ; Set up UART baud rate to 9600 bauds @ 50MHz:
          ; (50E6 / 9600) = 5208d = 1458h
          mvi   a,#0H14           
          out   UART_BAUDH
          mvi   a,#0H58
          out   UART_BAUDL
          
          ; Clear P2 port
          mvi   a,#0H0
          out   P2OUT
          
          ; Set up interrupts
          mvi   a,#0H8           ; Enable UART irq...
          out   IRQ_ENABLE
          ei                    ; ...and enable interrupts in the CPU
        
          ; print hello message to console
          lxi   h,msg_hello
          call  print_string

forever:          
          in    P1IN
          mov   c,a
          rlc   
          rlc
          add   c
          out   P2OUT
          jmp   forever

          di
          hlt
done:     jmp   done 

msg_hello: .ascii "\n\r\nHello World!$\000"          
          
;irq_uart: UART interrupt processing 
irq_uart:
          push  h
          push  psw
          
          ; Deal with RX interrupt (if any) first and then the TX interrupt.
          in    UART_STATUS     ; Is there new data in the RX register?
          ani   MASK_RX_IRQ
          jz    irq_uart_rx_done ; If there isn't, process TX interrupt.
          
          ; Process UART RX interrupt
irq_uart_rx:     
          mvi   a,MASK_RX_IRQ   ; Clear IRQ flag.
          out   UART_STATUS     
          in    UART_DATA       ; Get RX byte...
          out   P2OUT           ; ...display it in the output port...
          lhld  ptr_rx          ; ...and store it in the rx buffer.
          mov   m,a
          inx   h
          shld  ptr_rx          ; Update the rx buffer pointer.
          ; Note there's no check for RX buffer overrun! 

irq_uart_rx_done:
          ; Ok, RX is done. Now deal with TX irq, if any
          in    UART_STATUS     ; Is the TX buffer re new data in the RX register?
          ani   MASK_TX_IRQ
          jz    irq_uart_end    ; If there isn't, we're done.
          
          ; process UART TX interrupt
irq_uart_tx:
          mvi   a,MASK_TX_IRQ   ; Clear IRQ flag.
          out   UART_STATUS
          lhld  ptr_tx          ; Get next byte from the TX buffer 
          mov   a,m
          cpi   '$              ; Did we reach the end of the buffer?
          jz    irq_uart_tx_done ; If we did, we're done here...
          inx   h               ; ...otherwise increment the TX pointer...
          shld  ptr_tx
          out   UART_DATA       ; ...and transmit the data byte.
          
irq_uart_tx_done:
        
irq_uart_end:
          pop   psw             ; Done, quit.
          pop   h
          ei
          ret                
          ; Note there's no check for RX buffer overrun! we shouldn't need it 
          ; in this program, anyway.
     
   
;print_string: print $-terminated string at HL
; Returns as soon as the transmission has started; transmission proceeds in 
; 'background' through the UART interrupt service routine.
print_string:
          ; We don't check if there's a transmission going on, we just start
          ; transmitting. Not suitable for real use!
          mov   a,m             ; Get first character from string...
          inx   h               ; ...and move updated string pointer to TX  
          shld  ptr_tx          ; buffer pointer.
          cpi   '$              ; Kickstart transmission by sending 1st byte...
          jz    print_string_end; ...unless its the end of string marker.
          out   UART_DATA       ; 
print_string_end:
          ret

          
          ; data space, placed immediately after object code in memory
void_buffer:  .ascii "$"
ptr_tx:       .ds 2
ptr_rx:       .ds 2
rx_buffer:    .ds 32
              .ds 64
stack:        .ds 2
          ;.end
        
