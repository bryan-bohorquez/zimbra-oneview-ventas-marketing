-- Minimo 30 registros en todas las tablas. Ejecutar con MySQL 8.0.16+.
USE zimbra_db;
SET FOREIGN_KEY_CHECKS=0;
TRUNCATE TABLE alerta; TRUNCATE TABLE venta; TRUNCATE TABLE detalle_propuesta;
TRUNCATE TABLE propuesta; TRUNCATE TABLE interaccion; TRUNCATE TABLE prospecto;
TRUNCATE TABLE campania_contacto; TRUNCATE TABLE campania; TRUNCATE TABLE actividad_web;
TRUNCATE TABLE descarga_prueba; TRUNCATE TABLE contacto; TRUNCATE TABLE producto;
TRUNCATE TABLE empresa; TRUNCATE TABLE empleado;
SET FOREIGN_KEY_CHECKS=1;

INSERT INTO empleado(nombre,apellido,email,rol,password_hash,activo,fecha_ingreso)
WITH RECURSIVE seq(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM seq WHERE i<30)
SELECT CONCAT('Empleado',i),CONCAT('Demo',i),CONCAT('empleado',i,'@zimbra.demo'),
 CASE WHEN i<=15 THEN 'Vendedor' WHEN i<=22 THEN 'Analista de marketing' WHEN i<=26 THEN 'Gerente de ventas' ELSE 'Administrador' END,
 CONCAT('$2a$10$hashdemo-no-utilizable-',LPAD(i,2,'0')),TRUE,DATE_ADD('2025-01-01',INTERVAL i DAY) FROM seq;

INSERT INTO producto(codigo,nombre,edicion,tipo_licencia,buzones_incluidos,plazo_soporte_meses,precio_unitario,activo)
WITH RECURSIVE seq(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM seq WHERE i<30)
SELECT CONCAT('ZIM-',LPAD(i,3,'0')),CONCAT('Zimbra plan ',i),
 CASE WHEN MOD(i,3)=0 THEN 'Open Source' WHEN MOD(i,3)=1 THEN 'Network Estandar' ELSE 'Network Profesional' END,
 'Comercial',(MOD(i,5)+1)*100,12,500+i*75,TRUE FROM seq;

INSERT INTO empresa(razon_social,sector,pais,num_empleados,sitio_web,estado,fecha_registro)
WITH RECURSIVE seq(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM seq WHERE i<30)
SELECT CONCAT('Empresa Demo ',i),ELT(MOD(i-1,5)+1,'Educacion','Tecnologia','Salud','Gobierno','Telecomunicaciones'),
 ELT(MOD(i-1,5)+1,'Colombia','Mexico','Chile','Peru','Argentina'),20+i*17,CONCAT('https://empresa',i,'.example'),
 IF(MOD(i,4)=0,'Cliente','Prospecto'),DATE_SUB(CURRENT_DATE,INTERVAL i DAY) FROM seq;

INSERT INTO contacto(id_empresa,nombre,apellido,email,telefono,cargo,fuente_captacion,acepta_comunicaciones,fecha_registro)
WITH RECURSIVE seq(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM seq WHERE i<60)
SELECT MOD(i-1,30)+1,CONCAT('Contacto',i),CONCAT('Prueba',i),CONCAT('contacto',i,'@ejemplo.test'),
 CONCAT('+57-300-',LPAD(i,7,'0')),ELT(MOD(i-1,4)+1,'Director TI','Administrador','Gerente','Analista'),
 ELT(MOD(i-1,6)+1,'Sitio web','Campana','Webinar','Referido','Evento','Otra'),MOD(i,5)<>0,
 DATE_SUB(NOW(),INTERVAL i DAY) FROM seq;

INSERT INTO descarga_prueba(id_contacto,id_producto,fecha_descarga,fecha_vencimiento,estado)
WITH RECURSIVE seq(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM seq WHERE i<30)
SELECT i,i,DATE_SUB(NOW(),INTERVAL 30 DAY),DATE_ADD(CURRENT_DATE,INTERVAL 30 DAY),'Activa' FROM seq;

INSERT INTO prospecto(id_contacto,id_vendedor,puntaje,estado,fecha_creacion,fecha_calificacion)
WITH RECURSIVE seq(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM seq WHERE i<30)
SELECT i,MOD(i-1,15)+1,60,'Ganado',DATE_SUB(NOW(),INTERVAL i DAY),DATE_SUB(NOW(),INTERVAL 1 DAY) FROM seq;
INSERT INTO prospecto(id_contacto,id_vendedor,puntaje,estado,fecha_creacion,fecha_calificacion)
WITH RECURSIVE seq(i) AS (SELECT 31 UNION ALL SELECT i+1 FROM seq WHERE i<60)
SELECT i,MOD(i-31,15)+1,60,'Calificado',DATE_SUB(NOW(),INTERVAL i DAY),DATE_SUB(NOW(),INTERVAL 1 DAY) FROM seq;

-- Treinta visitas de retorno crean treinta alertas mediante trg_actividad_procesar.
INSERT INTO actividad_web(id_contacto,tipo_actividad,url_pagina,fecha_hora,puntos)
WITH RECURSIVE seq(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM seq WHERE i<30)
SELECT i+30,'Visita','/precios',DATE_SUB(NOW(),INTERVAL i HOUR),5 FROM seq;
INSERT INTO actividad_web(id_contacto,tipo_actividad,url_pagina,fecha_hora,puntos)
WITH RECURSIVE seq(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM seq WHERE i<30)
SELECT i+30,'Consulta de precios','/planes',DATE_SUB(NOW(),INTERVAL i MINUTE),20 FROM seq;

INSERT INTO campania(nombre,tipo,fecha_inicio,fecha_fin,presupuesto,id_responsable,estado)
WITH RECURSIVE seq(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM seq WHERE i<30)
SELECT CONCAT('Campana Demo ',i),ELT(MOD(i-1,4)+1,'Correo electronico','Webinar','Evento','Contenido web'),
 DATE_SUB(CURRENT_DATE,INTERVAL 10 DAY),DATE_ADD(CURRENT_DATE,INTERVAL 20 DAY),500+i*50,16+MOD(i-1,7),'En curso' FROM seq;

-- Insercion determinista de 30 pares de campaña-contacto con consentimiento.
INSERT INTO campania_contacto(id_campania,id_contacto,fecha_envio,abierto,clic)
SELECT c.rn,c.id_contacto,NOW()-INTERVAL 3 DAY,MOD(c.rn,2)=0,MOD(c.rn,4)=0
FROM (SELECT id_contacto,ROW_NUMBER() OVER(ORDER BY id_contacto) AS rn FROM contacto WHERE acepta_comunicaciones=TRUE) c
WHERE c.rn<=30;

INSERT INTO interaccion(id_prospecto,id_empleado,tipo,fecha_hora,resultado,notas)
WITH RECURSIVE seq(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM seq WHERE i<30)
SELECT p.id_prospecto,MOD(seq.i-1,15)+1,ELT(MOD(seq.i-1,4)+1,'Llamada','Correo','Reunion','Demostracion'),
 DATE_SUB(NOW(),INTERVAL seq.i HOUR),ELT(MOD(seq.i-1,3)+1,'Interesado','Requiere seguimiento','Solicita propuesta'),CONCAT('Seguimiento ',seq.i)
FROM seq JOIN prospecto p ON p.id_contacto=seq.i+30;

INSERT INTO propuesta(id_prospecto,id_empleado,fecha_emision,fecha_vencimiento,descuento_pct,total,estado,observaciones)
WITH RECURSIVE seq(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM seq WHERE i<30)
SELECT i,MOD(i-1,15)+1,DATE_SUB(CURRENT_DATE,INTERVAL 5 DAY),DATE_ADD(CURRENT_DATE,INTERVAL 25 DAY),5,0,'Aceptada',CONCAT('Propuesta simulada ',i) FROM seq;
INSERT INTO detalle_propuesta(id_propuesta,id_producto,cantidad,precio_unitario)
WITH RECURSIVE seq(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM seq WHERE i<30)
SELECT i,i,1,(SELECT precio_unitario FROM producto WHERE id_producto=i) FROM seq;

INSERT INTO venta(id_propuesta,fecha_cierre,monto_total,forma_pago,estado)
SELECT id_propuesta,CURRENT_DATE, total,ELT(MOD(id_propuesta-1,3)+1,'Transferencia','Tarjeta','Factura a credito'),'Cerrada'
FROM propuesta;
UPDATE empresa SET estado='Cliente';
UPDATE descarga_prueba SET estado='Convertida';

SELECT 'empresa' tabla,COUNT(*) filas FROM empresa UNION ALL
SELECT 'contacto',COUNT(*) FROM contacto UNION ALL SELECT 'empleado',COUNT(*) FROM empleado UNION ALL
SELECT 'producto',COUNT(*) FROM producto UNION ALL SELECT 'descarga_prueba',COUNT(*) FROM descarga_prueba UNION ALL
SELECT 'actividad_web',COUNT(*) FROM actividad_web UNION ALL SELECT 'campania',COUNT(*) FROM campania UNION ALL
SELECT 'campania_contacto',COUNT(*) FROM campania_contacto UNION ALL SELECT 'prospecto',COUNT(*) FROM prospecto UNION ALL
SELECT 'interaccion',COUNT(*) FROM interaccion UNION ALL SELECT 'propuesta',COUNT(*) FROM propuesta UNION ALL
SELECT 'detalle_propuesta',COUNT(*) FROM detalle_propuesta UNION ALL SELECT 'venta',COUNT(*) FROM venta UNION ALL
SELECT 'alerta',COUNT(*) FROM alerta;
