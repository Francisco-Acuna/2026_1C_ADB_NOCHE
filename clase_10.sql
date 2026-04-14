-- simulamos una separación de discos
-- sentencia DDL que crea una base de datos nueva y define explicitamente qué
-- archivos va a usar, dónde van a quedar y cómo van a crecer.
create database PruebaSeparacion
on -- la claúsula ON se usa para definir los archivos de datos de la base
(
	name = PruebaSeparacion_DATA, -- define el nombre lógico del archivo. Es el nombre
	-- que SQL Server usa internamente para referirse al archivo. No es el nombre físico
	-- del archivo.
	filename = 'C:\Users\smata\Administración BD\disco_de_datos\PruebaSeparacion.mdf',
	-- define la ruta física completa del archivo en el sistema operativo.
	-- indica en qué carpeta y con qué nombre real se va a quedar guardado el archivo.
	size = 20MB, -- indica el tamaño inicial con el que se crea el archivo de datos
	filegrowth = 10MB -- define el crecimiento automático del archivo.
)
LOG ON -- la cláusula LOG ON define el archivo de log de la base de datos
(
	name = PruebaSeparacion_Log,
	filename = 'C:\Users\smata\Administración BD\disco_de_logs\PruebaSeparacion_log.ldf',
	size = 20MB,
	filegrowth = 10MB
);
GO

-- query para verificar cómo quedaron registrados los archivos de la base 
select	name as NombreLogico,
		physical_name as RutaFisica,
		type_desc as TipoArchivo
from	sys.master_files
where	database_id = DB_ID('PruebaSeparacion');
GO

/*
La base master es la base de datos principal del sistema de SQL Server.
Cada instancia de SQL Server tiene varias system databases, y la más importante es master.
Su función es guardar la información crítica del servidor.
En master se guarda información como:
- qué bases de datos existen
- dónde están los archivos mdf y ldf
- qué logins existen
- configuraciones del servidor
- etc.
*/

/*
TempDB no es una base más. Es una base del sistema que SQL Server usa como área de trabajo
temporal. Sirve para tablas temporales, algunos resultados intermedios, ciertos ordenamientos
o agrupaciones grandes, trabajo interno del servidor, etc.
Se crea desde cero cada vez que el servicio arranca.
Es la base que SQL Server utiliza cuando necesita espacio auxiliar temporal para resolver
algo que no puede o no conviene resolver solo en memoria.
No contiene información del negocio.
No se backupea.
Hay que auditar la cantidad de archivos y el crecimiento.
Cuando muchas consultas ejecutan operaciones temporales al mismo tiempo, pueden competir
por estructuras internas. Si dejamos un solo archivo, todos los procesos pasarían por la
misma puerta. Al crear varios archivos con el mismo tamaño,distribuimos la carga. Al tener
más archivos, SQL Server tiene más estructuras internas para gestionar el trabajo en paralelo.

Sobre lo que vemos en la configuración actual podemos notar que 8MB de tamaño inicial 
está bien para un ambiente educativo, pero para una empresa real, se llenaría enseguida.
Estos archivos deberían nacer (initial size) según el entorno, puede ser de 256MB, 512MB,
1GB.
La ubicación está en disco C: en un servidor real, esto debería estar en un disco separado
y rápido, no donde está instalado Windows.
Archivos de Datos (data file):
MDF (Master Data File): Es el primer archivo de datos. Siempre tiene que haber uno y suele
tener la extensión .mdf, por lo general es tempdev
NDF (Secondary Data File): Son los archivos de datos secundarios. Tienen la extensión .ndf
serían los archivos temp2, temp3, etc.

Autogrowth
Es la regla que indica cuánto crece cuando se llene el archivo. Si el archivo llegó al 
límite y necesitamos guardar un dato más, el motor se frena y agranda el archivo.
A nivel corporativo, nunca se utiliza un crecimiento por porcentaje (%). Crecer un 10%
en una base de 100MB es rápido, crecer un 10% en una base de 1TB, congelaría el motor 
mientras Windows reserva los 100GB de disco. El porcentaje se hace cada vez más grande.
Para tempdb y para entornos profesionales suele preferirse un crecimiento fijo en MB,
porque es más predecible y fácil de controlar.
Para bases de datos de usuarios de pequeña a mediana, se suele utilizar valores fijos de 
64MB o 128MB.
*/	

-- vemos el detalle
use tempdb;
GO
-- esta query muestra el estado actual
select		name, -- nombre lógico del archivo
			physical_name, -- ruta física
			size, -- tamaño del archivo en páginas de 8KB
			growth, -- incremento del crecimiento configurado
			max_size -- tamaño máximo permitido del archivo
from		sys.database_files; -- consulta la información de los archivos de la base actual

-- esta query muestra el tamaño inicial configurado
select		name,
			physical_name,
			size,
			growth,
			max_size
from		sys.master_files
where		database_id = DB_ID('tempdb');

-- como tempdb no creció desde que arrancó SQL Server, ambas consultas pueden dar el mismo 
-- resultado.
-- max_size = -1 significa que no le pusimos un tope manual, puede seguir creciendo hasta
-- que se llene el disco.
-- ambas salidas están representadas en páginas de 8KB
-- size: 1024 x 8KB -> 8192KB -> / 1024 -> 8GB
-- growth: 8192 x 8KB -> 65536KB -> 1024 -> 64GB 

-- hacemos un pequeño ejercicio para generar un crecimiento de tempdb
create table #DemoTempdb -- crea una tabla temporal. El prefijo # indica que es una tabla 
-- temporal. Vive de forma temporal. Pertenece a la sesión actual. En la práctica, esa tabla
-- se crea físicamente en tempdb
(
	id int identity(1,1) primary key, -- identity(1,1) hace que SQL genere automáticamente los
	-- valores. El primer 1 es el valor inicial y el segundo es el incremento.
	relleno char(4000) not null
);
GO

insert into #DemoTempdb (relleno) -- indica que se van a insertar filas en la tabla temporal
select top(30000) replicate('X', 4000) -- construimos los datos que vamos a insertar
-- top(3000) limita el resultado final para que solo se devuelvan las primeras 30.000 filas.
-- la función replicate repite una cadena una cierta cantidad de veces.
-- en este caso, repite el caracter 'X' 4.000 veces consecutivas, creando una cadena larga
-- de 4.000 caracteres de longitud.
from sys.all_objects a -- es una vista del sistema que contiene objetos de la base actual
cross join sys.all_objects b; -- cross join hace el producto cartesiano
-- utilizamos sys.all_objects dos veces con cross join para generar muchísimas filas rápidamente
-- no nos interesan los datos de esos objetos, solo nos interesa tener una fuente grande de filas
-- para poblar la tabla temporal
GO

-- ==============================================================================
/*
Definir un tamaño inicial razonable evita múltiples eventos de crecimiento.
Esto es importante porque el Auotgrowth genera una pausa momentánea, un evento de expansión,
fragmentación potencial y escribe en disco.
Por lo cual, lo ideal es que el archivo ya nazca con un tamaño cercano al que sabemos que
se  necesitará.
*/

-- consulta que muestra el crecimiento actual
use Laboratorio_SQL;
Go
select		name,
			size * 8 / 1024 as SizeMB,
			case
				when is_percent_growth = 1 then cast(growth as varchar) + '%'
				else cast(growth * 8 / 1024 as varchar) + 'MB'
			end as Growth
from		sys.database_files;
GO
-- CAST es una función de conversión de tipos de datos en SQL
-- sirve para transformar un valor de un tipo de dato a otro tipo de dato.
-- growth indica cuánto crece el archivo cada vez que ocurre un autogrowth, pero
-- no siempre está en MB.
-- is_percent_growth es un flag (0/1) que indica cómo interpretar el growth
-- 0 = crecimiento fijo (en páginas, convertible a MB)
-- 1 = crecimiento en porcentaje (%)

-- ------------------------------------------------------------------

/*
El recovery model define cómo SQL Server administra el registro de transacciones
y qué capacidades de recuperación va a tener. Define hasta dónde puede recuperar
la base y cómo administrar el log.
Los tres modelos son:
- SIMPLE
- FULL
- BULK_LOGGED

SIMPLE
- El log sigue existiendo y se usa normalmente.
- pero el espacio se puede reutilizar automáticamente después de un checkpoint.
- SQL Server limpia esa parte del log (LDF) para volver a usar ese espacio libre. Técnicamente
a esta acción de borrado automático se la llama "truncamiento de log" (Log Truncation).
- no permite recuperación a un punto en el tiempo mediante backups de log. Ya que no se 
pueden hacer backups de los logs.
- Se utiliza en bases de laboratorio, desarrollo, testing y bases no críticas.
- Es el modelo más fácil de administrar. No obliga a planificar backups de log.
- Si ocurre un problema, se pierde toda la información desde el último backup que hayamos hecho.

FULL
- registra completamente la actividad transaccional.
- permite hacer backups de logs.
- permite recuperación a punto en el tiempo.
- requiere estrategia real de backups.
- si no hacemos backups de logs cuando corresponde, el log puede crecer mucho.
- es el modelo típico para bases de producción importantes, donde la pérdida de datos debe 
ser mínima.
- lleva más trabajo administrativo, pero brinda más capacidad de protección y recuperación.

BULK_LOGGED
- es parecido al FULL para muchas operaciones
- pero ciertas operaciones masivas se registran de forma mínima
- puede reducir el crecimiento en cargas masivas
- tiene limitaciones de recuperación punto en el tiempo si un log backup contiene operaciones 
bulk.
- Se usa cuando queremos ejecutar ciertas operaciones de volumen grande con menos impacto
en el log que en el FULL. El caso típico es una carga masiva o manteniminto puntual, luego
se vuelve al modelo FULL.
- conviene solo en situaciones puntuales, por ejemplo en una carga masiva planificada.
*/

/*
	Compatibility level
	No cambia la versión física del motor. La instancia sigue siendo SQL Server 2022.
	Lo que cambia es el nivel de compatibilidad de esa base para ciertos comportamientos del lenguaje
	y del optimizador.
	El compatibility level ayuda a que una base vieja pueda convivir en un motor más nuevo sin romper
	inmediatamente ciertos comportamientos esperados por la aplicación.
*/

-- query para ver el nivel de compatibilidad y el modelo de recuperación
select		name as BaseDeDatos,
			compatibility_level AS NivelDeCompatibilidad,
			recovery_model_desc as ModeloDeRecuperacion
from		sys.databases;

-- -------------------------------------------------------------------------------------------

/*
Pasos para revisar una conexión.

PING (Packet Internet Groper)
Es la herramienta más antigua y básica de diagnóstico de red. Utiliza un protocolo especial llamado
ICMP (Internet Control Message Protocol -> protocolo usado para enviar mensajes de control, informar
errores y hacer diagnósticos de red). Envía un paquete básico a una dirección IP y espera que esa 
máquina le devuelva un "eco" (respuesta). Mide si el equipo destino está encendido, conectado a la red 
y cuánto tarda el viaje en milisegundos.
Uso profesional actual: se usa como el paso 1, ping ayuda a responder si hay alcance IP básico y si 
el host responde a ICMP Echo. 
Por seguridad, muchos firewall bloquean el protocolo ICMP. O sea que la máquina puede estar prendida y
funcionando, pero el ping da "Tiempo de espera agotado" porque el firewall lo ignora.
Comando: ping xxx.xxx.x.xx (número de IP)

TELNET
Es un protocolo de red antiquísimo (de 1.969) diseñado para acceder a equipos de forma remota mediante
una consola de texto. A nivel de diagnóstico, se usa para forzar una conexión a un puerto específico
utilizando el protocolo TCP. 
Uso profesional actual: está obsoleto y desaconsejado. Históricamente, los administradores lo usaban
para probar si un puerto estaba abierto. Si la pantalla se ponía negra, el puerto estaba abierto. Si
daba error, estaba cerrado. El problema (y por eso se desancoseja su uso) es que envía la información
en un texto plano (no tiene seguridad). Ya no viene instalado por defecto en Windows 10 ni 11. Para
usarlo hay que ir al panel de control y habilitar la característica manualmente, lo cual en un servidor
de producción es una pérdida de tiempo y un riesgo.
Comando: telnet xxx.xxx.x.xx 1433 

Test-NetConnection
Es un cmdlet (comando) nativo de PowerShell introducido en las versiones modernas de Windows. Es la
evolución definitiva. Combina lo mejor del Ping y lo mejor del Telnet en una sola herramienta moderna.
Hace un ping (ICMP) y un intento de conexión al puerto, simultáneamente.
Uso profesional actual: Es una de las herramientas más útiles y actuales para diagnosticar conectividad
TCP hacia servicios como SQL Server.
Comando: Test-NetConnection -ComputerName xxx.xxx.x.xx -Port 1433 
Devuelve un reporte estructurado y claro, donde la variable TcpTestSucceeded indica true o false si el 
firewall y el servicio están permitiendo la entrada.
*/

/*
ErrorLog
Es el registro principal de eventos relevantes del motor. Es una fuente básica de diagnóstico. No 
reemplaza monitoreo ni auditoría formal, pero sí es una de las primeras evidencias que revisa un buen
admistrador. Sirve para ver el arranque del servicio, detectar errores, revisar intentos de login fallidos,
ver mensajes operativos relevantes. Cada vez que el servicio de SQL Server arranca, hace un chequeo 
interno de todo el hardware, cuenta cuántos núcleos tiene, revisa cuánta memoria tiene asignada, 
inicializa TempDB y finalmente, si todo está bien, escribe la frase "Recovery is complete. This is an
informational message only. No user action is required".
Técnicamente es un archivo de texto plano guardado en el disco rígido del servidor. Su función es
escribir ahí todo lo que considera importante.
Lo utilizamos para:
- Diagnóstico de arranque: si el servicio no levanta, el ErrorLog indica el por qué.
- Auditoría de seguridad: registra intentos de login fallidos (por ejemplo, alguien intentó ingresar
como 'sa' 50 veces)
- Salud de las bases: avisa si alguna base de datos está corrupta o necesita un chequeo.
*/

EXEC sp_readerrorlog;

/*
Una instalación profesional no termina cuando el motor enciende. Termina cuando quedó 
documentado y respaldado. Antes de entregar un servidor, siempre hay que generar un punto 
cero. Es un concepto de buenas prácticas de administración.
Es un en definitiva un backup full que hacemos inmediatamente después de terminar la
instalación y configuración, antes de que nadie empiece a cargar datos reales. 
Principalmente se hace de las bases del sistema, en especial de las bases master y msdb
base master: contiene todos los logins, la configuración de los discos, la memoria y parámetros
del servidor.
base msdb: contiene las tareas programadas y configuraciones de backups.
Un backup que nunca fue probado, es un backup hipotético.
*/

backup database msdb
to disk = 'C:\Users\smata\Administración BD\backups\Msdb_PuntoCero.bak'
with init, format, stats = 10;
-- to disk: define la ruta, no debería utilizarse el disco C:
-- with init: sobreescribe el archivo si ya existe, si no lo ponemos, agrega el backup al final del
-- archivo anterior, creando un archivo cada vez más grande, inmanejable.
-- format: asegura que el archivo tenga un encabezado limpio, es ideal para un backup inicial.
-- stats=10 : muestra el progreso en la pestaña de mensajes (10%, 20%, etc) es un feedback visual.

restore verifyonly from disk = 'C:\Users\smata\Administración BD\backups\Msdb_PuntoCero.bak';
-- restore verifyonly: lee el archivo recién creado, verifica el checksum y confirma que es legible,
-- sin intentar sobreescribir la base master real (lo cual nos daría error, porque está en uso).

-- --------------------------------------------------------------------------------------

-- Baseline de rendimiento
-- Es una medición inicial del estado del servidor recién instalado  configurado.
-- Sirve como referencia futura. Si no sabemos cómo estaba el servidor cuando estaba sano, después
-- no tenemos con qué comparar.

select
		total_physical_memory_kb / 1024 as [RAM Total del servidor (MB)],
-- esto toma el total de RAM física del servidor (viene en Kilobytes), lo dividimos por 1024
-- para mostrarlo en Megabytes y que sea más legible
		available_physical_memory_kb / 1024 as [RAM Libre del sistema (MB)],
-- muestra cuánta RAM libre queda en el Sistema Operativo, si ese número es muy bajo, 
-- Windows se va a poner lento.
		system_memory_state_desc AS [Estado Salud Memoria]
-- muestra una descripción en texto (High/Low)
-- High = sobra memoria (estado saludable)
-- Low = falta memoria (peligroso)
from	sys.dm_os_sys_memory;
-- consulta desde la vista del sistema que lee directamente del Sistema Operativo

-- cuánto consume SQL Server
select	physical_memory_in_use_kb / 1024 as [Consumo SQL (MB)]
from	sys.dm_os_process_memory;
-- esta vista del proceso lee internamente

/*
sp_helpfile
Este es un procedimiento almacenado del sistema. Es un pequeño programa que ya viene hecho por Microsoft.
Cuando se ejecuta devuelve una tabla, entre los principales datos podemos encontrar:
- name: el nombre lógico (ej. master, tempdev). Es como SQL llama al archivo internamente.
- filename: la ruta física en el disco rígido (ej. C:\...\master.mdf). Sirve para saber dónde están 
guardados los archivos realmente.
- size: el tamaño actual del archivo.
Esta información debería quedar documentada.
*/
EXEC sp_helpfile;

-- Al ejecutar esta query, si devuelve datos, el servicio corre y la conexión funciona
select	
		sqlserver_start_time AS [Hora de inicio],
		datediff(minute, sqlserver_start_time, getdate()) AS [Minutos encendido],
		@@servername AS [Nombre del Servidor]
from	sys.dm_os_sys_info;

-- Checklist profesional de entrega
/*
Instalar no es el final. Documentar es el final. Si mañana el servidor falla, el documento nos sirve
para reflejar el punto inicial. Puerto, memoria, modelo de recuperación, rutas de archivos, etc.
Un DBA no confía en su memoria, confía en su documentación.
Al documento que se genera al final de una instalación se lo suele llamar "Operational Handover",
"Pase a Operaciones" u "Hoja de Instalación".
*/

/*
Actividad nro. 1
Objetivo: documentar el estado actual del servidor SQL instalado.
Utilizando SQL Server Management Studio (SSMS), Configuration Manager y el administrador de tareas,
deberán navegar entre las interfaces para encontrar los datos solicitados.
Complete la hoja de instalación con los valores reales configurados en la pc.
Entregar este documento en formato txt o md.
*/



