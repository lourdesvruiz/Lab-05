 ; Archivo:	multiplesdisplaysss.s
 ; Dispositivo:	PIC16F887
 ; Autor:	Lourdes Ruiz
 ; Compilador:	pic-as (v2.32), MPLABX V5.50
 ;                
 ; Programa:	contador que incrementa y decrementa usando dos pushbuttons en portb 
 ;              valor de contador se muestra en decimal en tres displays multiplexados 
 ; Hardware:	LEDs en el puerto A, pushbuttons en el puerto B, transistores en puerto C
 ;              y display en puerto D 
 ;                       
 ; Creado: 22 ago, 2021
 ; Última modificación: 25 ago, 2021
 
 PROCESSOR 16F887
 #include <xc.inc>
 
 ;configuration word 1
  CONFIG FOSC=INTRC_NOCLKOUT	// Oscillador Interno sin salidas, XT
  CONFIG WDTE=OFF   // WDT disabled (reinicio repetitivo del pic)
  CONFIG PWRTE=OFF   // PWRT enabled  (espera de 72ms al iniciar)
  CONFIG MCLRE=OFF  // El pin de MCLR se utiliza como I/O
  CONFIG CP=OFF	    // Sin protección de código
  CONFIG CPD=OFF    // Sin protección de datos
  
  CONFIG BOREN=OFF  // Sin reinicio cuándo el voltaje de alimentación baja de 4V
  CONFIG IESO=OFF   // Reinicio sin cambio de reloj de interno a externo
  CONFIG FCMEN=OFF  // Cambio de reloj externo a interno en caso de fallo
  CONFIG LVP=OFF        // programación en bajo voltaje permitida
 
 ;configuration word 2
  CONFIG WRT=OFF    // Protección de autoescritura por el programa desactivada
  CONFIG BOR4V=BOR40V // Reinicio abajo de 4V, (BOR21V=2.1V)

  
;------------------macros-------------------  

;--------calculos de temporizador--------
;temporizador = 4*TOSC*TMR0*Prescaler 
;TOSC = 1/FOSC 
;TMR0 = 256 - N (el cual indica el valor a cargar en TMR0)
;¿valor necesario para 0.005s? 
;(4*(1/4MHz))*TMR0*256 = 0.005s
;TMR0 = 20
;256-20 =  / N=236
reinicio_timer0   macro  ;macro para reiniciar el contador del timer0
    banksel  PORTA 
    movlw    236
    movwf    TMR0
    bcf      T0IF    ;se apaga la bandera luego del reinicio
    endm   
    
wdivl   macro   divisor     ;macro para división 
   movwf       var_dos
   clrf        var_dos+1
   
   incf        var_dos+1    ;revisar cuantas veces se ha restado 
   movlw       divisor      ;se quiere restar el "divisor"
   
   subwf       var_dos, f   ;se le resta el divisor 
   btfsc       CARRY        ;revisar si hubo acarreo. si si, ya se paso la resta (ej. 9/10)
   goto        $-4          ;si no, se vuelve a repetir la resta
                            ;
   decf        var_dos+1, W ;guardar los resultados en W
   movwf       cociente     ;resultado de la división
   
   movlw       divisor
   addwf       var_dos, W   ;debido a que quedo "negativo" se le suma el divisor 
   movwf       residuo      ;el resultado sería el residuo  
   endm
   
;---------------variables--------------------    
 PSECT udata_bank0 ;common memory
    banderas:    DS  1
    display_var: DS  3
    contador:    DS  1
    var_dos:     DS  2
    cociente:    DS  1
    residuo:     DS  1
    unidad:      DS  1
    decena:      DS  1
    centena:     DS  1 
        
 PSECT udata_shr ;common memory
    W_TEMP:	 DS  1 ;1 byte
    STATUS_TEMP: DS  1 ;1 byte
        
 PSECT resVect, class=CODE, abs, delta=2
 ;--------------vector reset------------------
 ORG 00h	;posición 0000h para el reset
 resetVec:
     PAGESEL main
     goto main
 
 PSECT intVect, class=CODE, abs, delta=2
 ;--------------interrupt vector------------------
 ORG 04h	;posición 0004h para las interrupciones
 push:
    movwf   W_TEMP
    swapf   STATUS, W
    movwf   STATUS_TEMP
    
 isr:
    btfsc   RBIF       ;si la bandera esta prendida entra a la siguiente instruccion
    call    interrupt_oc_b
    btfsc   T0IF 
    call    interrupt_tmr0
    
 pop:
    swapf   STATUS_TEMP, W
    movwf   STATUS
    swapf   W_TEMP, F
    swapf   W_TEMP, W
    retfie
 
 ;-------------subrutinas de interrupcion-----
 interrupt_oc_b:
    banksel  PORTA
    btfss    PORTB, 0
    incf     PORTA
    btfss    PORTB, 1
    decf     PORTA 
    bcf      RBIF 
 return
 
 interrupt_tmr0:                ;subrutina para la interrupción en el contador del timer0
    reinicio_timer0
    clrf     PORTC              ;clear al puerto donde se encuentran los transistores
                        
    btfss    banderas, 0        ;revisa si la bandera está setteada, si sí, se salta la instrucción 
    goto     display0
    
    btfss    banderas, 1
    goto     display1
    
    btfss    banderas, 2
    goto     display2 
   
 display0:   
    bsf     banderas, 0        ;se prende el primer bit de banderas
    movf    display_var, W
    movwf   PORTD
    bsf     PORTC, 0
   
    return  
    

display1:
    bcf     banderas, 0 
    bsf     banderas, 1      ;se prende el segundo bit y se apaga el primer bit 
    movf    display_var+1, W
    movwf   PORTD
    bsf     PORTC, 1
    
    return
     
    
display2:
    bcf     banderas, 1 
    bsf     banderas, 2      ;se prende el tercer bit y se apaga el segundo bit
    movf    display_var+2, W
    movwf   PORTD
    bsf     PORTC, 2 
    clrf    banderas         ;se hace un clear a banderas para limitar (solo los primeros tres bits)
    
    return 
 
 PSECT code, delta=2, abs
 ORG 100h	; posición para el código
 
 ;configuración de tablas de 7 segmentos
 seg7_tabla:
    clrf   PCLATH
    bsf    PCLATH, 0   ; PCLATH = 01 PCL = 02
    andlw  0x0f        ; limitar a numero "f", me va a poner en 0 todo lo superior y lo inferior, lo deja pasar (cualquier numero < 16)
    addwf  PCL         ; PC = PCLATH + PCL + W (PCL apunta a linea 103) (PC apunta a la siguiente linea + el valor que se sumo)
    retlw  00111111B   ;return que tambien me devuelve una literal (cuando esta en 0, me debe de devolver ese valor)
    retlw  00000110B   ;1
    retlw  01011011B   ;2
    retlw  01001111B   ;3
    retlw  01100110B   ;4
    retlw  01101101B   ;5
    retlw  01111101B   ;6
    retlw  00000111B   ;7
    retlw  01111111B   ;8
    retlw  01101111B   ;9
    retlw  01110111B   ;A
    retlw  01111100B   ;B
    retlw  00111001B   ;C
    retlw  01011110B   ;D
    retlw  01111001B   ;E
    retlw  01110001B   ;F
 
 ;-------------configuración------------------
 main:
    call    config_io
    call    config_clock
    call    config_timer0
    call    config_interrupt_oc_b
    call    config_int_enable
    banksel PORTA
    
  
;------------loop principal---------          
 loop:
    movf    PORTA, W   
    
    call    hundreths
    call    preparar_displays
   
    
    goto    loop        ; loop forever

 ;------------sub rutinas------------
    
preparar_displays:      ;mueve la variable y la muestra en el display 
    
    movf    unidad, W
    call    seg7_tabla
    movwf   display_var+2
    
    movf    decena, W
    call    seg7_tabla
    movwf   display_var+1
    
    movf    centena, W
    call    seg7_tabla
    movwf   display_var+0
    return
    
config_clock:
    banksel OSCCON 
    bsf     IRCF2   ;IRCF = 110 4MHz 
    bsf     IRCF1
    bcf     IRCF0
    bsf     SCS     ;configurar reloj interno
    return

config_timer0:
    banksel TRISA 
    ;configurar OPTION_REG
    bcf     T0CS   ;reloj interno (utlizar ciclo de reloj)
    bcf     PSA    ;asignar el Prescaler a TMR0
    bsf     PS2
    bsf     PS1 
    bsf     PS0    ;PS = 111 (1:256)
    reinicio_timer0
    return
    
config_interrupt_oc_b:
    banksel TRISA
    bsf     IOCB, 0
    bsf     IOCB, 1  ;habilitar el interrupt on-change
    
    banksel PORTA 
    movf    PORTB, W ;al leer termina la condicion de "mismatch" (de ser distintos)
    bcf     RBIF     ;se settea la bandera 
    return
 
config_io:
    banksel ANSEL   ;nos lleva a banco 3 (11)
    clrf    ANSEL   ;configuración de pines digitales 
    clrf    ANSELH
    
    banksel TRISA    ;nos lleva a banco 1 (01)
    clrf    TRISA    ;salida para LEDs (contador)
    clrf    TRISC
    clrf    TRISD
    bsf     TRISB, 0 ; RB0 como entrada para pushbutton
    bsf     TRISB, 1 ; RB1 como entrada para pushbutton
    bcf     TRISB, 2
  
    ;-------------------------Weak Pull Ups----------------------------------
    bcf     OPTION_REG, 7 ;bit con lógica negada (RBPU) para habilitar pull ups 
    bsf     WPUB, 0
    bsf     WPUB, 1       ;habilitar weak pull ups de RB0 Y RB1 (entradas)
    
    ;---------------------valores iniciales en banco 00--------------------------
    banksel PORTA   ;nos lleva a banco 0 (00)
    clrf    PORTA 
    clrf    PORTB 
    clrf    PORTC 
    clrf    PORTD 
    return 
    
config_int_enable: 
    bsf     GIE    ;Intcon (interrupciones globales habilitadas)
    bsf     RBIE
    bcf     RBIF
    
    bsf     T0IE 
    bcf     T0IF 
    return 

hundreths:                      ;subrutina de división
   wdivl  100
   movf   cociente, W          
   movwf  centena 
   movf   residuo, W           ;el residuo se pasa a dividir en "decenas"
   
tenths:
   wdivl  10
   movf   cociente, W 
   movwf  decena  
   movf   residuo, W           ;el residuo se guarda en la variable "unidad" (no hay necesidad de dividir dentro de 1)
   
units:
   movwf  unidad 
   return

    
END 


