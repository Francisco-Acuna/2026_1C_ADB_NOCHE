-- creamos una base de datos 
create database Clase_demo;
go
-- preguntamos en dónde se guardó
select	name, physical_name
from	sys.master_files
where	database_id = DB_ID('Clase_demo');

/*
GO es un delimitador, no es una instrucción SQL. Se usa desde
el cliente (SSMS) para indicar que ahí termina un lote de
instrucciones. Todo lo que esté antes de GO se envía todo
junto para ejecutarse y lo que viene después es otro lote
separado. El ";" separa sentencias dentro de un mismo lote
y GO delimita lotes distintos. Si no se utiliza GO, el motor
de SQL Server va a intentar ejecutar todo en secuencia.
Sin el GO, en este caso, el motor podría fallar, porque 
intentaría hacer un select de una base que por ahí aún no
terminó de crearse.
sys.master_files es una vista de catálogo del sistema que
contiene una fila por cada archivo de todas las bases de 
datos del servidor.
name es el nombre lógico del archivo
physical_name es la ruta real del disco
where database_id = DB_ID('Clase_demo') filtra los resultados
La función DB_ID traduce el nombre de la base de datos a un
*/

use Clase_demo;

create table Alumnos(
	Legajo int,
	Nombre varchar(50)
);

insert into Alumnos values (2,'Juan Perez');

select * from Alumnos;

select	DB_NAME(database_id) as Base,
		file_id,
		num_of_bytes_written,
		num_of_writes
from	sys.dm_io_virtual_file_stats(DB_ID('Clase_demo'), null);

checkpoint;
/*
la función sys.dm_io_virtual_file_stats() es una Vista de Gestión Dinámica (DMV) que
devuelve estadísticas de E/S (Entrada/Salida) para los archivos de datos y log.
Recibe 2 parámetros: database_id (en este caso es el de Clase_demo) y file_id
ponemos NULL para que nos devuelva todos los archivos de esa base.
db_name(database_id) traduce el ID numérico al nombre legible de la base de datos
file_id identifica al archivo
num_of_bytes_written es el total de bytes que se grabaron en ese archivo desde que el
servicio de SQL Server se inició.
num_of_writes es la cantidad de veces (operaciones) que SQL Server le pidió al disco
escribir algo.
*/