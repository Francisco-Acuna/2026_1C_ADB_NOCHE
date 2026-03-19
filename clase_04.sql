-- Cómo ver el puerto para poder cambiarlo tanto para instancias por default como nombradas
-- abrir SQL Server Configuration Manager -> SQL Server Network configuration ->
-- Protocols for (nombre de la instancia) -> doble click sobre TCP/IP -> ver IPALL

-- cómo saber el nombre del host de la pc -> cmd -> hostname
-- cómo saber la ip del host -> cmd -> ipconfig -> IPV4

/*
Para averiguar si un puerto está libre u ocupado, ejecutar en CMD o PS:
netstat -ano | findstr :1433
Para leer el resultado: si no sale nada, el puerto está libre. Nadie lo está usando.
Si sale una o más líneas, el puerto está ocupado.
La última columna indica el PID (Process ID) de quién está ocupando el puerto.
netstat -> Network Statistics. Es el comando base para ver qué pasa en la red de la PC.
-a -> indica que queremos ver todas las conexiones y puertos de escucha. Si no lo ponemos, solo
va a mostrar las conexiones activas. Pero oculta los puertos que están esperando (listening).
-n (numeric/numérico) -> indica que queremos los números de IP y que no los transforme a nombres
Es más exacto y rápido para identificar.
-o (owner/propietario) -> indica el PID del proceso que es dueño de esa conexión.
| (pipe/tubería) -> este símbolo agarra el resultado de lo generado anteriormente y se lo pasa
a la instrucción que sige.
findstr (find string/buscar cadena) -> es un filtro, lo anterior arroja cientos de líneas, por eso
lo usamos para buscar solo lo que nos interesa.
1433 -> es el puerto que queremos buscar.
para conocer quién está ocupando el puerto:
CMD o PS
tasklist /FI "PID eq 12940" (cambiar el número por el PID que les muestre)
tasklist -> es el programa principal, su función es listar todas las tareas (procesos) corriendo en
el sistema.
/FI -> FILTER/FILTRO, le indica al comando que no le muestre todo, solo lo que queremos filtrar
PID -> es la columna por la cual queremos filtrar
eq -> EQuals (igual a)
12940 -> el número de PID que obtuvimos con la ejecución anterior.
*/

