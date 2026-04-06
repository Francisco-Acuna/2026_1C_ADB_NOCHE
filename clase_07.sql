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
-- size: 1024 x 8KB -> 8192KB -> / 1024 -> 8MB
-- growth: 8192 x 8KB -> 65536KB -> 1024 -> 64MB 

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
