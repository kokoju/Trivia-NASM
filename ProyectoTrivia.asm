%include "io.mac"

; ProyectoTrivia.asm
; Lee un archivo hasta EOF y genera un número aleatorio entre 1 y 30
; Y almacena a sus respectivos arreglos los valores

;=====================================
;Definicion de nombres
;=====================================

bufsize EQU 300	;  Máxima cantidad de bytes por pregunta
tamannio_pregunta EQU 80  ; Máximo tamaño que puede tener una pregunta
tamannio_respuesta EQU 2  ; Máximo tamaño que puede tener una respuesta
tamannio_opcion EQU 45  ; Máximo tamaño que puede tener una opción
tamannio_totalidad_pregunta EQU 7  ; Cantidad de líneas que tiene cada pregunta en el archivo (pregunta + 4 opciones + respuesta + puntaje)

bloque_opciones EQU tamannio_opcion*4  ; Máximo de tamaño que puede tener un bloque de 4 opciones
cantidad_preguntas EQU 10  ; Cantida de preguntas que se le muestran al usuario en una "run"


.DATA
filename db "PreguntasTrivia.txt",0 ; nombre del archivo
msg_bienvenida db "¡Bienvenido a nuestro juego de Trivia! Se te asignarán 10 preguntas aleatorias de nuestra base de datos, y deberás responder con la letra que contenga la opción correcta. ¡Buena suerte!", 0
; Mensajes de comprobación y estado
msg_correcto db "¡CORRECTO!", 0  ; Mensaje para respuestas correctas
msg_incorrecto db "¡INCORRECTO! La respuesta correcta era la opción ", 0  ; Mensaje para respuestas incorrectas
; Mensajes para mostrar el score


msg_indicar_respuesta db "Su respuesta a esta pregunta es: ", 0
msg_puntaje_1 db "¡Has acumulado un total de ", 0
msg_puntaje_2 db " punto(s)!", 0
msg_error db "Error leyendo archivo: intente nuevamente", 0
msg_volver_jugar db "¿Desea volver a jugar? (S/N): ", 0
msg_valor_pregunta_1 db "Esta pregunta vale por ", 0
msg_valor_pregunta_2 db " punto(s)", 0

.UDATA
contador_puntaje resd 1  ; Contador de puntaje total
contador_enter resd 1  ; Cuenta la cantidad de Enters para asi ver las preguntas correctamente
buffer resb bufsize ; Buffer como mediador para guardar todo a sus arreglos
buftrash resb 1	 ; Buffer para guardar un valor hasta saltar x lineas

arreglo_preguntas resb tamannio_pregunta*cantidad_preguntas ;reserva 10 preguntas
arreglo_opciones resb bloque_opciones*cantidad_preguntas ;las 4 opciones de las 10 preguntas
arreglo_respuestas resb tamannio_respuesta*cantidad_preguntas ;las respuestas de las 10 preguntas
arreglo_puntaje resb tamannio_respuesta*cantidad_preguntas  ; Arreglo que guarda el puntaje de cada pregunta

n_pregunta resd 1  ; Pregunta actual (índice dentro de casi TODOS los arreglos, exceputando arreglo_num_elegidos)

arreglo_num_elegidos resd cantidad_preguntas  ; Arreglo que guarda los números elegidos para ser presentados
n_repetidos resd 1  ;  Cantidad que guarda la cantidad de numeros en el arreglo (se guarda en un DWORD por comodidad para trabajar con ESI y EDI posteriormente)

;================================================================
; En resumen cada pregunta posee 84 bytes como maximo
; Cada pregunta posee 4 opciones de respuesta de 45 bytes maximo
; Y cada respuesta correcta posee 2 bytes (A y nulo; por ejemplo) 
;================================================================

.CODE
        .STARTUP
inicio:  ; Incio de nuestro código
    mov DWORD [n_pregunta], 0  ; Se limpia n_pregunta
    mov DWORD [contador_puntaje], 0  ; Se limpia el contador de puntaje
    jmp abrir_archivo;  ; Saltamos a la apertura del archivo

inicio_reinicio:  ; Etiqueta para reiniciar el juego
   ; LIMPIEZA DE TODOS LOS ARREGLOS Y VARIABLES
   xor EAX, EAX  ; Ponemos AL en 0 (contenido que vamos a copiar con stosb)
   lea EDI, [arreglo_preguntas]  ; Dirección de inicio del arreglo de preguntas
   mov ECX, tamannio_pregunta * cantidad_preguntas  ; Movemos a ECX la cantidad total de bytes a limpiar (tamaño de arreglo_preguntas)
   rep stosb  ; rep stosb copia el contenido de AL (0) en [EDI] ECX veces

   lea EDI, [arreglo_opciones]  ; Dirección de inicio del arreglo de opciones
   mov ECX, bloque_opciones * cantidad_preguntas  ; Movemos a ECX la cantidad total de bytes a limpiar (tamaño de arreglo_opciones)
   rep stosb  ; rep stosb copia el contenido de AL (0) en [EDI] ECX veces

   lea EDI, [arreglo_respuestas]  ; Dirección de inicio del arreglo de respuestas
   mov ECX, tamannio_respuesta * cantidad_preguntas  ; Movemos a ECX la cantidad total de bytes a limpiar (tamaño de arreglo_respuestas)
   rep stosb  ; rep stosb copia el contenido de AL (0) en [EDI] ECX veces

   lea EDI, [arreglo_puntaje]  ; Dirección de inicio del arreglo de puntajes
   mov ECX, tamannio_respuesta * cantidad_preguntas  ; Movemos a ECX la cantidad total de bytes a limpiar (tamaño de arreglo_puntaje)
   rep stosb  ; rep stosb copia el contenido de AL (0) en [EDI] ECX veces

   lea EDI, [arreglo_num_elegidos]  ; Dirección de inicio del arreglo de números elegidos
   mov ECX, cantidad_preguntas
   rep stosd  ; rep stosd copia el contenido de EAX (0) en [EDI] ECX veces

   lea EDI, [n_repetidos]  ; Dirección de inicio de n_repetidos
   mov ECX, 1
   rep stosd  ; rep stosd copia el contenido de EAX (0) en [EDI] ECX veces

   mov DWORD [contador_enter], 0  ; Se limpia el contador enters
   mov DWORD [n_pregunta], 0  ; Se limpia n_pregunta

abrir_archivo:  ; Proceso para abrir nuestro archivo de preguntas
    mov eax, 5  ; sys_open
    mov ebx, filename  ; Nombre del archivo
    mov ecx, 0  ; Modo: ReadOnly
    int 0x80  ; Se llama a la interrupción
    cmp eax, 0  ; El resultado fue guardado en EAX: si este dió 0, hubo un error
    js  error  ; Si error, salir
    mov ebx, eax  ; Descriptor del archivo es guardado en EBX


randint:  ; Rutina para volver a llamar randint (numero entre 0 y 29) e iniciar todo otra vez
    mov DWORD [contador_enter], 0
    push ebx 	; Push necesario para mantener el descriptor en EBX

    rdtsc  ; Se toma el contador de ciclos de reloj del procesador desde el arranque del sistema
    xor edx, eax  ; Desorden
    rol edx, 13  ; Desorden
    xor eax, edx  ; Desorden
    mov ebx, 35  ; Número maximo
    xor edx, edx  ; Desorden
    div ebx  ; Divide y el número generado obtenido es pseudo-aleatorio (residuo se encuentra en EDX)
    
    pop ebx  ; Se recupera nuestro registro EBX

;===================================================
; COMPROBAR SI ESTA REPETIDO EL NUMERO
;===================================================

    mov esi, 0  ; Índice para recorrer arreglo_repetidos

verificar_repetido:  ; Etiqueta para verificar si el número obtenido del randint está repetido
    cmp esi, DWORD [n_repetidos]  ; Comparamos con DWORD[n_repetidos] para ver si llegamos al siguiente espacio vacío (DWORD[n_repetidos] es un número)
    je guardar_numero  ; Si llegamos al final, no está repetido

    mov eax, [arreglo_num_elegidos + esi*4] ; Mientras no se haya llegado al final de los números obtenidos, se lee el siguiente número guardado
    cmp eax, edx  ; Se compara con el obtenido por nuestro randint 
    je repetir_randint  ; Si coincide, significa que el número ya está y debemos repetir el randint
    inc esi  ; Si no son iguales, procedemos a incrementar esi y revisar el siguiente dígito
    jmp verificar_repetido  ; Saltamos a la misma etiqueta en la que nos encontramos

guardar_numero:  ; Etiqueta a la que llegamos si el número que obtuvimos no está repetido: 
    mov eax, DWORD [n_repetidos]  ; Ponemos en EAX la cantidad de números que habíamos contabilizado antes
    mov [arreglo_num_elegidos + eax*4], edx ; A la siguiente casilla libre se le asigna EDX (resultado de randint)
    inc DWORD [n_repetidos]  ; Incrementamos la cantidad de números guardados para apuntar al siguiente espacio vacío
    ; Se continua con el flujo normal (saltar_loop, etc.)
    jmp no_repetido

repetir_randint:  ; Etiqueta a la que llegamos cuando el número obtenido estaba repetido
    jmp randint  ; Se repite el randint

no_repetido:  ; Etiqueta a la que llegamos cuando nuestro número no fue repetido
    imul edx, tamannio_totalidad_pregunta  ; Se multiplica nuestro resultado de randint por 6
    mov DWORD [contador_enter], edx  ;  Se guarda el valor de los enters a saltar en el contador

;==================================================================================
; Explicacion:
; En el documento no existen nulos solo enters donde se puede leer todo, asi pues
;***************
;* Pregunta1\n *
;* Opcion1\n   *
;* Opcion2\n   *
;* Opcion3\n   *
;* Opcion4\n   *
;* Respuesta\n *
;* Puntaje\n   *
;* Pregunta2\n *
;***************
;
; Para llegar de pregunta1 a pregunta2 se pasan por 6 enters, por ende sacando
; el numero aleatorio de randint y luego multiplicandolo por 6, logramos saltar
; n enters hasta la pregunta deseada
;=================================================================================


; === Leer hasta x enters, pues es el final de la pregunta ===
saltar_loop:  ; Etiqueta encargada de posicionarnos dentro del archivo, haciendo que apuntemos a la pregunta que necesitamos 
    mov eax, 3  ; sys_read
    mov ecx, buftrash  ; Dirección del buffer temporal de 1 byte
    mov edx, 1  ; Leemos 1 byte
    int 0x80  ; Procedemos con la interrupción
    cmp eax, 0  ; El resultado fue guardado en EAX: si este dió 0, hubo un error
    jle error  ; EOF o error
    	
    mov al, [buftrash]  ; Cargar el byte leído
    cmp al, 0x0A  ; ¿El byte es un enter?
    jne saltar_loop  ; Si no es un enter, procedemos a leer siguiente

    ; si es enter
    dec DWORD [contador_enter]  ; Decrementamos el contador de enters recorridos 
    cmp DWORD [contador_enter], 0  ; Si este llega a su fin, procedemos a leer el archivo
    je leer_archivo  ; Etiqueta para leer el archivo
    jmp saltar_loop  ; Si no se ha llegado al final, se repite otra vez el loop

;=== Leer archivo ===
;Tras saltar la cantidad de enters que dice el archivo ahora si leemos, iniciando en la pregunta que obtubimos

leer_archivo:  ; Etiqueta para la lectura del archivo
    mov eax, 3  ; sys_read
    mov ecx, buffer  ; Buffer donde se guarda la lectura
    mov edx, bufsize  ; Cantidad máxima a leer
    int 0x80  ; Se hace la interrupción
    cmp eax, 0  ; El resultado fue guardado en EAX: si este dió 0, hubo un error
    jle error  ; EOF o error
    
    ; En este momento de la ejecución el buffer tiene la pregunta que queríamos, entonces procedemos a pasarla a su respectivo espacio
    ; Preparativos para copiar pregunta
    mov ecx, DWORD [n_pregunta]  ; Se pone en ECX el número de pregunta en el que estamos actualmente (índice del arreglo de preguntas)
    lea ESI, buffer  ; Con lea, cargamos la dirección del buffer en ESI
    mov EAX, ECX  ; Ponemos en EAX el número de pregunta en el que estamos
    imul EAX, tamannio_pregunta  ; Mutiplicamos el número de pregunta por el tamaño que tiene una pregunta (esta operación nos termina dando el offset del siguiente espacio vacío disponible dentro del arreglo de preguntas)
    lea EDI, [arreglo_preguntas + EAX]  ; Ponemos a EDI a apuntar a este espacio vacío

;=== Guardar la pregunta al arreglo correspondiente ===

; EDI = Apuntando al inicio del espacio vacío de arreglo_preguntas
; ESI = Apuntando al inicio del buffer que tiene el texto que queremos
guardar_pregunta:  ; Etiqueta para guardar las cadenas necesarias
    mov al,[ESI]  ; Mueve el byte revisado del buffer a AL
    mov [EDI], al  ; Lo copia en el arreglo    
    inc ESI  ; Siguiente del buffer
    inc EDI  ; Siguiente del arreglo
    cmp al, 0x0A  ; Se compara con enter (indica el final de la pregunta)
	
    je guardar_opciones  ; Si se llegó al final, pasamos a guardar las opciones
    jmp guardar_pregunta  ; Si no ha llegado al enter, se sigue leyendo y copiando del buffer

;=== Guardar opciones de la respectiva pregunta ===

guardar_opciones:  ; Preparativos para guardar las opciones de la pregunta
   mov DWORD[EDI-1], 0  ; Se almacena un nulo al final de la pregunta (sirve para eliminar el carácter del enter)
   mov BYTE[contador_enter], 0 ; Se reinicia el índice de opción a 0

   ; Calcular dirección inicial de la primera opción:
   mov eax, ecx  ; Se pone en EAX el contenido de ECX (recordando que ECX tiene el número de pregunta en el que estamos actualmente)
   imul eax, bloque_opciones  ; 180 = 45*4 (tamaño bloque por pregunta)
   lea edi, [arreglo_opciones + eax]  ; Así como se hizo con las preguntas, ponemos a EDI a apuntar al siguiente espacio vacío donde escribiremos las opciones que obtuvimos
   

ciclo_opciones:  ; Etiqueta del ciclo de lectura de opciones
   mov al,[ESI]  ; Mueve el byte revisado del buffer a AL
   mov [EDI], al  ; Lo copia en el arreglo    
   inc ESI  ; Siguiente del buffer
   inc EDI  ; Siguiente del arreglo
 
   cmp al, 0x0A  ; Si hay un enter, debemos recalcular y seguir con la siguiente opción de pregunta
   je siguiente_opcion  ; Se llegó a un enter, entonces se pasa a la siguiente opción
   jmp ciclo_opciones  ; Si no, seguimos leyendo normal


siguiente_opcion:  ; Etiqueta para el paso entre opciones

; === Recálculo de posición y ajuste de opción ===
   mov BYTE[EDI-1], 0  ; Se reemplaza el enter con un 0
   inc DWORD [contador_enter]  ; Siguiente opcion (ajuste de opción al incrementar el contador de enters que llevamos)  

   ; Cálculo de nueva posición para la siguiente opción
    mov eax, ecx  ; Se pone en EAX el contenido de ECX (número de pregunta en el que estamos actualmente)
    imul eax, bloque_opciones  ; 180 = 45*4 (tamaño bloque por pregunta)
    mov ebx, DWORD [contador_enter]  ; Ponemos en EBX el contador de enters que llevamos (número entre 0 y 3)
    imul ebx, tamannio_opcion  ; Este número guardado en EBX es multiplicado por el tamaño que consume cada opción, asegurando que el espacio que registramos es el indicado
    add eax, ebx  ; Le sumamos EBX a nuestro offset, almacenado en EAX
    lea edi, [arreglo_opciones + eax]  ; Ponemos a EDI a apuntar a ese espacio recién calculado

; === Se compara con 4: si es el caso, se terminó de guardar ===
   cmp DWORD [contador_enter], 4  ; Si el contador de enters llegó a 4, significa que leímos todas las opciones y pasamos la guardado de respuesta
   je guardar_respuesta  ; Paso al guardado de respuesta
   jmp ciclo_opciones  ; Si no se llegó a los 4 enters, se siguen guardando opciones en su respectivo arreglo

; === Guardado de respuesta ===

guardar_respuesta:  ; Etiqueta encargada de guardar la respuesta
   lea EDI, [arreglo_respuestas + ecx*tamannio_respuesta] ;  Cada respuesta contiene 2 bytes, guardada en su respectiva posición según lo que almacena ECX (índice de pregunta actual de los arreglos)
   mov al, [ESI]  ; ESI siempre apunta a lo siguiente a guardar, según el formato del documento
   mov [EDI], al   ; Se guarda el carácter en su respectivo espacio
   inc EDI  ; Se incrementa en 1 para revisar lo que es el enter
   mov BYTE[EDI], 0  ; Se guarda nulo en ese espacio para borrarlo
   inc ESI  ; Siguiente en el buffer
   inc ESI ;  Siguiente en el buffer (para saltar el enter)

; === Guardado de puntaje ===
guardar_puntaje:  ; Etiqueta encargada de guardar el puntaje
   lea EDI, [arreglo_puntaje + ecx*tamannio_respuesta] ;  Cada puntaje contiene 2 bytes, guardada en su respectiva posición según lo que almacena ECX (índice de pregunta actual de los arreglos)
   mov al, [ESI]  ; ESI siempre apunta a lo siguiente a guardar, según el formato del documento
   mov [EDI], al   ; Se guarda el carácter en su respectivo espacio
   inc EDI  ; Se incrementa en 1 para revisar lo que es el enter
   mov BYTE[EDI], 0  ; Se guarda nulo en ese espacio para borrarlo

;=== guarda las respuestas en el arreglo ===
 
ciclo_aleatorio:  ; Etiqueta necesaria para medir el ciclo en el que vamos
   cmp ecx, 9 ;  Si se llegó a la última pregunta, se acaba el ciclo
   je cerrar_archivo2  ; Si ya tenemos todas nuestras preguntas, nos ponemos a preguntar
   inc DWORD [n_pregunta]  ; Si no se ha llegado, le sumamos uno al ECX y continua repetimos

cerrar_archivo:  ; Etiqueta hecha para cerrar archivo y repetir el ciclo de conseguir otra pregunta
   mov eax, 6          ; sys_close
   int 0x80
   jmp abrir_archivo

cerrar_archivo2:  ; Etiqueta para cerrar archivo, pero sin volver a saltar a nuestro ciclo
   mov eax, 6  ; sys_close
   int 0x80  ;  Llamamos a una interrupción (con el fin de cerrar el archivo)
   PutStr msg_bienvenida  ; Le damos la bienvenida al usuario
   nwln  ; Salto de línea
   mov DWORD [n_pregunta], 0  ; Ponemos nuestro índice de pregunta en 0s
   lea EDX, contador_puntaje  ; Pone a EDX a apuntar a nuestro contador de puntaje
    
mostrar_preguntas_usuario:  ; Etiqueta hecha para comenzar a hacerle preguntas al usuario
   call logica_preguntas  ; Hacemos una llamada para hacer la lógica de las preguntas
   call pedir_respuesta_usuario  ; Después de imprimir el contenido, se le pide una respuesta al usuario
   inc DWORD [n_pregunta]  ; Suma al DWORD [n_pregunta] para pasar a los siguientes elementos de impresión
   cmp DWORD [n_pregunta], 10  ; ¿Hemos llegado a la última pregunta? 
   je  preguntar_fin;  Si es así, terminamos de registrar
   jmp mostrar_preguntas_usuario
    
logica_preguntas:
; IMPRESIÓN DE PREGUNTA
   mov EAX, DWORD [n_pregunta]  ;  Ponemos en EAX el índice del arreglo que llevamos
   imul EAX, tamannio_pregunta  ; Lo multiplicamos por el tamaño de una pregunta
   lea ESI, [arreglo_preguntas + EAX]  ; Ponemos a ESI a apuntar a ese espacio
   call imprimir_letras  ; Se imprime la pregunta
   nwln  ; Salto de línea
    
; IMPRESIÓN DE OPCIONES
   xor EBX, EBX  ;  Se deja el EBX en 0s (limpiamos registro)
    
loop_impresion_opciones:  ; Bucle para la impresión de las 4 opciones
   mov EAX, DWORD [n_pregunta]  ;  Ponemos en EAX el índice del arreglo que llevamos
   mov ECX, EBX  ; Ponemos en ECX por la opción de pregunta que vamos revisando 
   imul EAX, bloque_opciones  ; Lo multiplicamos por el tamaño del bloque de opciones
   imul ECX, tamannio_opcion  ; Lo multiplicamos por el tamaño de una sola opción
   add EAX, ECX  ; Se suman EAX y ECX para obtener el offset indicado
   lea ESI, [arreglo_opciones + EAX]  ; Ponemos a ESI a apuntar al espacio indicado del arreglo_opciones
   call imprimir_letras;  ; Imprimimos
   nwln  ; Salto de línea
   inc EBX  ; Se incrementa EBX porque se revisó ya una opción
   cmp EBX, 4  ; Si EBX es igual a 4, significa que revisamos ya todas las opciones
   je return  ; Si ya se imprimieron las opciones, se vuelve al mostrar_preguntas_usuario
   jmp loop_impresion_opciones

   
imprimir_letras:  ; Impresión letra por letra
   cmp WORD [ESI], 0  ; Se compara la letra en [ESI] con 0
   je return  ; Si es 0, se llegó al final de la pregunta y se acaba la ejecución
   mov AL, [ESI]  ; Si no es 0, se utiliza PutCh para imprimir en pantalla hasta que se llegue al nulo
   PutCh AL  ; Ponemos el byte en pantalla
   inc ESI  ; Incrementamos ESI para revisar el siguiente espacio
   jmp imprimir_letras  ; Repetimos el ciclo de impresión
  
 
pedir_respuesta_usuario:  ; Lógica para pedirle respuesta al usuario
   mov ECX, DWORD [n_pregunta]  ;  Ponemos en ECX el índice del arreglo que llevamos
   imul ECX, tamannio_respuesta  ; Se calcula el offset dentro de arreglo_respuestas
   lea ESI, [arreglo_puntaje + ECX]  ; ESI apunta a la posición correcta del arreglo de puntajes
   PutStr msg_valor_pregunta_1  ; Mensaje de puntaje 1 se muestra en pantalla
   PutCh [ESI]  ; Se muestra el puntaje de la pregunta actual
   PutStr msg_valor_pregunta_2  ; Mensaje de puntaje 2 se muestra en pantalla
   nwln  ; Salto de línea
   PutStr msg_indicar_respuesta  ; Se pone en pantalla el mensaje de respuesta
   GetCh  AL  ; Se almacena la respuesta del usuario en AL
   nwln  ; Salto de línea
   lea ESI, [arreglo_respuestas + ECX]  ; ESI apunta a la posición correcta del arreglo de respuestas
   call procesar_char  ; Pasamos el contenido de AL a mayúsculas
   cmp AL, [ESI]  ; Comparamos la respuesta correcta con la respuesta introducida
   je respuesta_correcta  ; Si ambos espacios son iguales, significa que la respuesta es correcta
   jmp respuesta_incorrecta  ; Si son distintos, la  respuesta es incorrecta

; === Paso de respuestas a mayúscula===
procesar_char:  ; Etiqueta para pasar de minúsculas a mayúsculas
	cmp AL, 'a'  ; Si el carácter es inferior a la a minúscula
	jl no_operacion  ; No es un carácter en minúscula
	cmp AL, 'z' ; Si el carácter es superior a la z minúscula
	jg no_operacion;  No es un carácter minúscula

transformar_mayuscula:  ; Etiqueta a la que se llega si la letra es minúscula
	add AL, 'A'-'a'  ; Se tranforma con una suma la letra en mayúscula
	ret  ; Se devuelve al call inicial

no_operacion:  ; Etiqueta a la que se llega el carácter no es minúscula (una mayúscula o cualquier carácter aparte)
	ret  ; Se devuelve al call inicial, no hay transformación real

respuesta_correcta:  ; Etiqueta cuando el usuario acierta la pregunta
   mov EAX, DWORD [arreglo_puntaje + ECX]  ; Guarda el contenido de la posición del puntaje en AL
   sub EAX, '0'  ; Convierte el carácter a su valor numérico
   add DWORD [EDX], EAX  ; Incrementa el puntaje
   PutStr msg_correcto  ; Mensaje de éxito
   nwln  ; Salto de línea
   PutStr msg_puntaje_1  ; Mensaje de puntaje 1 se muestra en pantalla
   PutInt [EDX]  ; Se muestra el puntaje
   PutStr msg_puntaje_2  ; Mensaje de puntaje 2 se muestra en pantalla
   nwln  ; Salto de línea
   nwln  ; Salto de línea
   jmp return  ; Vuelta a mostrar_preguntas_usuario

respuesta_incorrecta:  ; Etiqueta cuando el usuario falla la pregunta
   PutStr msg_incorrecto  ; Mensaje de fallo
   PutCh [ESI]  ; Se muestra la respuesta correcta (almacenada en ESI)
   nwln  ; Salto de línea
   PutStr msg_puntaje_1  ; Mensaje de puntaje 1 se muestra en pantalla
   PutInt [EDX]  ; Se muestra el puntaje
   PutStr msg_puntaje_2  ; Mensaje de puntaje 2 se muestra en pantalla
   nwln  ; Salto de línea
   nwln  ; Salto de línea
   jmp return  ; Vuelta a mostrar_preguntas_usuario
 
        
return:  ; Etiqueta para hacer rets condicionales
   ret  ; Return para cuando hay un call

error:  ; Etiqueta de error
	mov EAX, 6
	int 0x80
	nwln  ; Salto de línea
	PutStr msg_error  ; Mensaje de error
	nwln  ; Salto de línea
   jmp fin  ; Salto al final del programa

preguntar_fin:  ; Etiqueta para preguntar si desea volver a jugar
   PutStr msg_volver_jugar  ; Se pregunta al usuario si desea volver a jugar
   GetCh AL  ; Se obtiene la respuesta del usuario
   nwln  ; Salto de línea
   call procesar_char  ; Pasamos el contenido de AL a mayúsculas
   cmp AL, 'S'  ; Se compara si la respuesta es Sí
   je inicio_reinicio  ; Si es así, se reinicia el juego
		       ;Si no acaba el programa. 


fin:
    .EXIT


;TODO: mensaje de error y revisar repetidos

;================================================
;Informacion útil
;================================================


;Por pregunta son 81 bytes de offset
;Por bloque de opciones son 172 bytes y por opcion son 43
;Por respuesta son 2 bytes

;Si deseo llegar a la segunda opcion de la pregunta 8 debo
;En arreglo_pregunta es:
;(n_pregunta-1)*tamannio_pregunta
;En arreglo_opciones es:
;[n_pregunta * tamannio_bloque_opciones + tamannio_opcion * n_opcion]
;En arreglo_respuestas:
;(n_pregunta-1)*tamannio_respuesta
