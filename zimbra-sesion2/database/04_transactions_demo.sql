USE zimbra_db;

-- T1. Propuesta con una linea valida y una linea invalida recuperada con savepoint.
START TRANSACTION;
INSERT INTO propuesta(id_prospecto,id_empleado,fecha_emision,fecha_vencimiento,descuento_pct,total,estado,observaciones)
VALUES(1,1,CURRENT_DATE,DATE_ADD(CURRENT_DATE,INTERVAL 30 DAY),5,0,'Borrador','Demo T1');
SET @id_propuesta_demo=LAST_INSERT_ID();
SAVEPOINT sp_cabecera;
INSERT INTO detalle_propuesta(id_propuesta,id_producto,cantidad,precio_unitario)
SELECT @id_propuesta_demo,id_producto,2,precio_unitario FROM producto WHERE id_producto=1;
SAVEPOINT sp_linea;
-- Siguiente INSERT falla intencionalmente por cantidad=-1. En Workbench ejecutarlo como
-- sentencia individual; luego ejecutar ROLLBACK TO SAVEPOINT y continuar.
INSERT INTO detalle_propuesta(id_propuesta,id_producto,cantidad,precio_unitario)
SELECT @id_propuesta_demo,id_producto,-1,precio_unitario FROM producto WHERE id_producto=2;
ROLLBACK TO SAVEPOINT sp_linea;
UPDATE propuesta SET estado='Enviada' WHERE id_propuesta=@id_propuesta_demo;
COMMIT;

-- T2. Aceptar y generar venta atomica. Ejecutar como bloque separado tras T1.
START TRANSACTION;
UPDATE propuesta SET estado='Aceptada' WHERE id_propuesta=@id_propuesta_demo AND estado='Enviada';
CALL generar_venta(@id_propuesta_demo,'Transferencia');
COMMIT;

-- T3. El trigger acumula puntos y alerta si la visita pertenece a un prospecto calificado.
START TRANSACTION;
SAVEPOINT sp_actividad;
INSERT INTO actividad_web(id_contacto,tipo_actividad,url_pagina,puntos)
VALUES(1,'Visita','/precios',10);
COMMIT;

-- T4. Reporte del mes actual.
CALL reporte_mensual(CURRENT_DATE);

-- ROLLBACK total demostrativo: quitar comentarios y ejecutar el bloque para observar que
-- el producto conserva su precio original.
-- START TRANSACTION;
-- UPDATE producto SET precio_unitario=-1 WHERE id_producto=1; -- falla por CHECK
-- ROLLBACK;
