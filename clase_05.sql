-- validación de IFI
select servicename, instant_file_initialization_enabled
from sys.dm_server_services;

-- sys.dm_server_services es una DMV = Dynamic Management View
-- Una DMV es una vista del sistema que devuelve información del estado interno del 
-- servidor o de la base. 

/*
Collation
No es solo el idioma de la base. Es el conjunto de reglas que definen cómo se comparan
los textos. Por ejemplo: sensibilidad a mayúsculas y minúsculas, sensibilidad a acentos.
Ordenamiento alfabético. Reglas lingüísticas.
Esto impacta directamente en búsquedas, comparaciones, ORDER BY, joins entre columnas de 
texto, compatibilidad entre bases o entre instancia y base.
Si mezclamos bases con collations distintas, pueden aparecer conflictos en joins o 
comparaciones.
Cambiar la collation del motor puede ser costoso. Podría requerir reconstrucción de bases
del sistema o una reinstalación o reconfiguración importante.
Elegir la collation depende de 3 cosas:
1- país/idioma principal
2- si es sistema nuevo o heredado
3- si es ambiente corporativo internacional.
Para entornos locales en español se suele utilizar Modern_Spanish_CI_AS.
Para empresas internacionales suele ser más común SQL_Latin1_General_CI_AS
*/

/*
Autenticación es la forma en que SQL Server verifica quién intenta entrar. En SQL Server
podemos trabajar con autenticación de Windows o con autenticación propia del motor, lo que
sería SQL Server Authentication.
Modo Windows: solo entran usuario de Windows. Es lo más seguro pero si se cae el controlador
de dominio, nadie puede entrar. A veces puede traer problemas para conectar desde Linux
o Docker.
Modo SQL: utiliza login y contraseña almacenados por SQL Server. Es obligatorio para poder
utilizar el usuario sa.
Modo mixto (Windows + SQL): permite usuarios de Windows y usuarios propios de SQL. En
laboratorios, desarrollo y muchos escenarios de soporte, Mixed Mode suele habilitarse por
compatibilidad y practicidad.
El usuario sa (System Administrator): no tiene límites. Se usa para emergencias o tareas
de mantenimiento profundo.
*/

select @@version;
-- el doble @@ en SQL Server se utiliza para invocar funciones del sistema 
-- predefinidas que devuelven información sobre el entorno, la configuración
-- o el estado de la sesión, sin necesidad de consultar tablas del sistema.

-- ver valores actuales de max server memory
select	name, -- trae el nombre de la opción de configuración
		value, -- trae el valor configurado
		value_in_use -- trae el valor efectivo en uso por el motor
from	sys.configurations -- vista de catálogo del sistema que expone opciones
-- de configuración del servidor
where	name IN('min server memory (MB)', 'max server memory (MB)');
-- filtra para mostrar solo esas dos opciones de memoria, en vez de traer
-- toda la configuración del servidor.

-- para modificar valores
-- habilitar opciones avanzadas
EXEC sp_configure 'show advanced options',1;
reconfigure;
-- sp_configure es el procedimiento del sistema para ver o cambiar 
-- configuraciones a nivel servidor.
-- 'show advanced options' es la opción que habilita ver y cambiar las
-- configuraciones avanzadas.
-- 1 significa activar esa opción.
-- reconfigure aplica el cambio que acabamos de hacer con sp_configure sin
-- necesidad de reiniciar el servidor.
-- si no ejecutamos reconfigure, el cambio configurado puede no pasar a 
-- uso efectivo.

-- cambiar la memoria máxima
exec sp_configure 'max server memory (MB)', 1024;
reconfigure;
-- cambia el valor de max server memory al valor que le asignamos, ese número debe
-- estar expresado en megabytes