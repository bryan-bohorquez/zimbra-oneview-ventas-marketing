-- Zimbra OneView - MySQL 8.0.16+ (CHECK constraints enforced).
CREATE DATABASE IF NOT EXISTS zimbra_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE zimbra_db;

CREATE TABLE IF NOT EXISTS empresa (
 id_empresa BIGINT AUTO_INCREMENT PRIMARY KEY,
 razon_social VARCHAR(120) NOT NULL UNIQUE, sector VARCHAR(60) NOT NULL, pais VARCHAR(60) NOT NULL,
 num_empleados INT NOT NULL, sitio_web VARCHAR(150),
 estado ENUM('Prospecto','Cliente','Inactiva') NOT NULL DEFAULT 'Prospecto', fecha_registro DATE NOT NULL DEFAULT (CURRENT_DATE),
 CHECK(num_empleados>0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS empleado (
 id_empleado BIGINT AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(60) NOT NULL, apellido VARCHAR(60) NOT NULL,
 email VARCHAR(100) NOT NULL UNIQUE,
 rol ENUM('Vendedor','Analista de marketing','Gerente de ventas','Administrador') NOT NULL,
 password_hash VARCHAR(255) NOT NULL, activo BOOLEAN NOT NULL DEFAULT TRUE, fecha_ingreso DATE NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS producto (
 id_producto BIGINT AUTO_INCREMENT PRIMARY KEY, codigo VARCHAR(20) NOT NULL UNIQUE, nombre VARCHAR(100) NOT NULL,
 edicion ENUM('Open Source','Network Estandar','Network Profesional') NOT NULL,
 tipo_licencia ENUM('Gratuita','Comercial') NOT NULL, buzones_incluidos INT NOT NULL,
 plazo_soporte_meses INT NOT NULL, precio_unitario DECIMAL(12,2) NOT NULL, activo BOOLEAN NOT NULL DEFAULT TRUE,
 CHECK(buzones_incluidos>0), CHECK(plazo_soporte_meses>=0), CHECK(precio_unitario>=0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS contacto (
 id_contacto BIGINT AUTO_INCREMENT PRIMARY KEY, id_empresa BIGINT NULL,
 nombre VARCHAR(60) NOT NULL, apellido VARCHAR(60) NOT NULL, email VARCHAR(100) NOT NULL UNIQUE,
 telefono VARCHAR(20), cargo VARCHAR(60),
 fuente_captacion ENUM('Sitio web','Campana','Webinar','Referido','Evento','Otra') NOT NULL,
 acepta_comunicaciones BOOLEAN NOT NULL DEFAULT TRUE, fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT fk_contacto_empresa FOREIGN KEY(id_empresa) REFERENCES empresa(id_empresa) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS descarga_prueba (
 id_descarga BIGINT AUTO_INCREMENT PRIMARY KEY, id_contacto BIGINT NOT NULL, id_producto BIGINT NOT NULL,
 fecha_descarga DATETIME NOT NULL, fecha_vencimiento DATE NOT NULL,
 estado ENUM('Activa','Vencida','Convertida') NOT NULL DEFAULT 'Activa',
 CHECK(fecha_vencimiento>DATE(fecha_descarga)),
 FOREIGN KEY(id_contacto) REFERENCES contacto(id_contacto) ON DELETE RESTRICT,
 FOREIGN KEY(id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS actividad_web (
 id_actividad BIGINT AUTO_INCREMENT PRIMARY KEY, id_contacto BIGINT NOT NULL,
 tipo_actividad ENUM('Visita','Descarga','Clic en correo','Formulario','Consulta de precios') NOT NULL,
 url_pagina VARCHAR(200), fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, puntos INT NOT NULL DEFAULT 0,
 CHECK(puntos>=0), FOREIGN KEY(id_contacto) REFERENCES contacto(id_contacto) ON DELETE RESTRICT,
 INDEX ix_actividad_contacto_fecha(id_contacto,fecha_hora)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS campania (
 id_campania BIGINT AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(100) NOT NULL UNIQUE,
 tipo ENUM('Correo electronico','Webinar','Evento','Contenido web') NOT NULL,
 fecha_inicio DATE NOT NULL, fecha_fin DATE NOT NULL, presupuesto DECIMAL(12,2) NOT NULL,
 id_responsable BIGINT NOT NULL, estado ENUM('Planeada','En curso','Finalizada','Cancelada') NOT NULL,
 CHECK(fecha_fin>=fecha_inicio), CHECK(presupuesto>=0),
 FOREIGN KEY(id_responsable) REFERENCES empleado(id_empleado) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS campania_contacto (
 id_campania BIGINT NOT NULL, id_contacto BIGINT NOT NULL, fecha_envio DATETIME NOT NULL,
 abierto BOOLEAN NOT NULL DEFAULT FALSE, clic BOOLEAN NOT NULL DEFAULT FALSE,
 PRIMARY KEY(id_campania,id_contacto), CHECK(clic=FALSE OR abierto=TRUE),
 FOREIGN KEY(id_campania) REFERENCES campania(id_campania) ON DELETE RESTRICT,
 FOREIGN KEY(id_contacto) REFERENCES contacto(id_contacto) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS prospecto (
 id_prospecto BIGINT AUTO_INCREMENT PRIMARY KEY, id_contacto BIGINT NOT NULL, id_vendedor BIGINT NULL,
 puntaje INT NOT NULL DEFAULT 0,
 estado ENUM('Nuevo','Calificado','Contactado','Propuesta enviada','Ganado','Perdido','Descartado') NOT NULL DEFAULT 'Nuevo',
 fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, fecha_calificacion DATETIME NULL, motivo_cierre VARCHAR(150),
 CHECK(puntaje>=0), CHECK(estado NOT IN('Perdido','Descartado') OR NULLIF(TRIM(motivo_cierre),'') IS NOT NULL),
 FOREIGN KEY(id_contacto) REFERENCES contacto(id_contacto) ON DELETE RESTRICT,
 FOREIGN KEY(id_vendedor) REFERENCES empleado(id_empleado) ON DELETE RESTRICT,
 INDEX ix_prospecto_estado_puntaje(estado,puntaje)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS interaccion (
 id_interaccion BIGINT AUTO_INCREMENT PRIMARY KEY, id_prospecto BIGINT NOT NULL, id_empleado BIGINT NOT NULL,
 tipo ENUM('Llamada','Correo','Reunion','Demostracion') NOT NULL, fecha_hora DATETIME NOT NULL,
 resultado ENUM('Sin respuesta','Interesado','Requiere seguimiento','No interesado','Solicita propuesta') NOT NULL,
 notas VARCHAR(300),
 FOREIGN KEY(id_prospecto) REFERENCES prospecto(id_prospecto) ON DELETE RESTRICT,
 FOREIGN KEY(id_empleado) REFERENCES empleado(id_empleado) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS propuesta (
 id_propuesta BIGINT AUTO_INCREMENT PRIMARY KEY, id_prospecto BIGINT NOT NULL, id_empleado BIGINT NOT NULL,
 fecha_emision DATE NOT NULL, fecha_vencimiento DATE NOT NULL, descuento_pct DECIMAL(5,2) NOT NULL DEFAULT 0,
 total DECIMAL(14,2) NOT NULL DEFAULT 0,
 estado ENUM('Borrador','Enviada','Aceptada','Rechazada','Vencida') NOT NULL DEFAULT 'Borrador', observaciones VARCHAR(300),
 CHECK(fecha_vencimiento>=fecha_emision), CHECK(descuento_pct BETWEEN 0 AND 25), CHECK(total>=0),
 FOREIGN KEY(id_prospecto) REFERENCES prospecto(id_prospecto) ON DELETE RESTRICT,
 FOREIGN KEY(id_empleado) REFERENCES empleado(id_empleado) ON DELETE RESTRICT,
 INDEX ix_propuesta_estado_vencimiento(estado,fecha_vencimiento)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS detalle_propuesta (
 id_detalle BIGINT AUTO_INCREMENT PRIMARY KEY, id_propuesta BIGINT NOT NULL, id_producto BIGINT NOT NULL,
 cantidad INT NOT NULL, precio_unitario DECIMAL(12,2) NOT NULL,
 subtotal DECIMAL(14,2) GENERATED ALWAYS AS (cantidad*precio_unitario) STORED,
 CHECK(cantidad>0), CHECK(precio_unitario>=0),
 FOREIGN KEY(id_propuesta) REFERENCES propuesta(id_propuesta) ON DELETE CASCADE,
 FOREIGN KEY(id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS venta (
 id_venta BIGINT AUTO_INCREMENT PRIMARY KEY, id_propuesta BIGINT NOT NULL UNIQUE, fecha_cierre DATE NOT NULL,
 monto_total DECIMAL(14,2) NOT NULL,
 forma_pago ENUM('Transferencia','Tarjeta','Factura a credito') NOT NULL,
 estado ENUM('Cerrada','Anulada') NOT NULL DEFAULT 'Cerrada', CHECK(monto_total>0),
 FOREIGN KEY(id_propuesta) REFERENCES propuesta(id_propuesta) ON DELETE RESTRICT,
 INDEX ix_venta_fecha_estado(fecha_cierre,estado)
) ENGINE=InnoDB;

-- Tabla añadida para materializar la alerta de retorno al sitio.
CREATE TABLE IF NOT EXISTS alerta (
 id_alerta BIGINT AUTO_INCREMENT PRIMARY KEY, id_prospecto BIGINT NOT NULL, id_actividad BIGINT NOT NULL UNIQUE,
 id_vendedor BIGINT NOT NULL, mensaje VARCHAR(240) NOT NULL, fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 leida BOOLEAN NOT NULL DEFAULT FALSE,
 FOREIGN KEY(id_prospecto) REFERENCES prospecto(id_prospecto) ON DELETE RESTRICT,
 FOREIGN KEY(id_actividad) REFERENCES actividad_web(id_actividad) ON DELETE RESTRICT,
 FOREIGN KEY(id_vendedor) REFERENCES empleado(id_empleado) ON DELETE RESTRICT,
 INDEX ix_alerta_vendedor_leida_fecha(id_vendedor,leida,fecha_hora)
) ENGINE=InnoDB;

USE zimbra_db;
DELIMITER $$

DROP TRIGGER IF EXISTS trg_actividad_procesar$$
CREATE TRIGGER trg_actividad_procesar AFTER INSERT ON actividad_web
FOR EACH ROW
BEGIN
 DECLARE v_id_prospecto BIGINT DEFAULT NULL;
 DECLARE v_id_vendedor BIGINT DEFAULT NULL;
 DECLARE v_estado VARCHAR(22) DEFAULT NULL;
 DECLARE v_puntaje INT DEFAULT NULL;
 SELECT id_prospecto,id_vendedor,estado,puntaje
 INTO v_id_prospecto,v_id_vendedor,v_estado,v_puntaje
 FROM prospecto WHERE id_contacto=NEW.id_contacto ORDER BY id_prospecto DESC LIMIT 1;
 IF v_id_prospecto IS NOT NULL THEN
   UPDATE prospecto SET puntaje=puntaje+NEW.puntos WHERE id_prospecto=v_id_prospecto;
   SET v_puntaje=v_puntaje+NEW.puntos;
   IF v_puntaje>=50 AND v_estado='Nuevo' THEN
     UPDATE prospecto SET estado='Calificado',fecha_calificacion=NEW.fecha_hora WHERE id_prospecto=v_id_prospecto;
     SET v_estado='Calificado';
   END IF;
   IF NEW.tipo_actividad='Visita' AND v_estado IN('Calificado','Contactado','Propuesta enviada') AND v_id_vendedor IS NOT NULL THEN
     INSERT IGNORE INTO alerta(id_prospecto,id_actividad,id_vendedor,mensaje)
     VALUES(v_id_prospecto,NEW.id_actividad,v_id_vendedor,'El prospecto calificado regreso al sitio web.');
   END IF;
 END IF;
END$$

DROP TRIGGER IF EXISTS trg_detalle_total_ai$$
CREATE TRIGGER trg_detalle_total_ai AFTER INSERT ON detalle_propuesta
FOR EACH ROW BEGIN
 UPDATE propuesta p SET p.total=(SELECT COALESCE(SUM(d.subtotal),0)*(1-p.descuento_pct/100)
   FROM detalle_propuesta d WHERE d.id_propuesta=NEW.id_propuesta)
 WHERE p.id_propuesta=NEW.id_propuesta;
END$$
DROP TRIGGER IF EXISTS trg_detalle_total_au$$
CREATE TRIGGER trg_detalle_total_au AFTER UPDATE ON detalle_propuesta
FOR EACH ROW BEGIN
 UPDATE propuesta p SET p.total=(SELECT COALESCE(SUM(d.subtotal),0)*(1-p.descuento_pct/100)
   FROM detalle_propuesta d WHERE d.id_propuesta=NEW.id_propuesta)
 WHERE p.id_propuesta=NEW.id_propuesta;
 IF OLD.id_propuesta<>NEW.id_propuesta THEN
   UPDATE propuesta p SET p.total=(SELECT COALESCE(SUM(d.subtotal),0)*(1-p.descuento_pct/100)
     FROM detalle_propuesta d WHERE d.id_propuesta=OLD.id_propuesta)
   WHERE p.id_propuesta=OLD.id_propuesta;
 END IF;
END$$
DROP TRIGGER IF EXISTS trg_detalle_total_ad$$
CREATE TRIGGER trg_detalle_total_ad AFTER DELETE ON detalle_propuesta
FOR EACH ROW BEGIN
 UPDATE propuesta p SET p.total=(SELECT COALESCE(SUM(d.subtotal),0)*(1-p.descuento_pct/100)
   FROM detalle_propuesta d WHERE d.id_propuesta=OLD.id_propuesta)
 WHERE p.id_propuesta=OLD.id_propuesta;
END$$

DROP TRIGGER IF EXISTS trg_propuesta_estado_bu$$
CREATE TRIGGER trg_propuesta_estado_bu BEFORE UPDATE ON propuesta
FOR EACH ROW
BEGIN
 IF NEW.estado<>OLD.estado AND NOT (
   (OLD.estado='Borrador' AND NEW.estado IN('Enviada','Rechazada')) OR
   (OLD.estado='Enviada' AND NEW.estado IN('Aceptada','Rechazada','Vencida'))
 ) THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Transicion de estado de propuesta no permitida';
 END IF;
 IF NEW.estado='Enviada' AND OLD.estado='Borrador' AND NOT EXISTS
   (SELECT 1 FROM detalle_propuesta WHERE id_propuesta=OLD.id_propuesta) THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='No se puede enviar una propuesta sin lineas';
 END IF;
END$$

-- Estas rutinas se llaman desde transacciones iniciadas por Java (Spring @Transactional).
DROP PROCEDURE IF EXISTS generar_venta$$
CREATE PROCEDURE generar_venta(IN p_id_propuesta BIGINT, IN p_forma_pago VARCHAR(25))
BEGIN
 DECLARE v_estado VARCHAR(10); DECLARE v_vencimiento DATE; DECLARE v_total DECIMAL(14,2);
 DECLARE v_id_prospecto BIGINT; DECLARE v_id_contacto BIGINT; DECLARE v_id_empresa BIGINT;
 SELECT estado,fecha_vencimiento,total,id_prospecto INTO v_estado,v_vencimiento,v_total,v_id_prospecto
 FROM propuesta WHERE id_propuesta=p_id_propuesta FOR UPDATE;
 IF v_estado IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Propuesta inexistente'; END IF;
 IF v_estado<>'Aceptada' OR v_vencimiento<CURRENT_DATE THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La propuesta debe estar aceptada y vigente';
 END IF;
 IF v_total<=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El total debe ser mayor que cero'; END IF;
 INSERT INTO venta(id_propuesta,fecha_cierre,monto_total,forma_pago)
 VALUES(p_id_propuesta,CURRENT_DATE,v_total,p_forma_pago);
 SELECT id_contacto INTO v_id_contacto FROM prospecto WHERE id_prospecto=v_id_prospecto;
 SELECT id_empresa INTO v_id_empresa FROM contacto WHERE id_contacto=v_id_contacto;
 UPDATE prospecto SET estado='Ganado' WHERE id_prospecto=v_id_prospecto;
 IF v_id_empresa IS NOT NULL THEN UPDATE empresa SET estado='Cliente' WHERE id_empresa=v_id_empresa; END IF;
 UPDATE descarga_prueba SET estado='Convertida' WHERE id_contacto=v_id_contacto AND estado='Activa';
END$$

DROP PROCEDURE IF EXISTS anular_venta$$
CREATE PROCEDURE anular_venta(IN p_id_venta BIGINT)
BEGIN
 DECLARE v_id_propuesta BIGINT; DECLARE v_id_prospecto BIGINT; DECLARE v_id_contacto BIGINT; DECLARE v_id_empresa BIGINT;
 SELECT id_propuesta INTO v_id_propuesta FROM venta WHERE id_venta=p_id_venta AND estado='Cerrada' FOR UPDATE;
 IF v_id_propuesta IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Venta inexistente o ya anulada'; END IF;
 SELECT p.id_prospecto,pr.id_contacto,c.id_empresa INTO v_id_prospecto,v_id_contacto,v_id_empresa
 FROM propuesta p JOIN prospecto pr ON pr.id_prospecto=p.id_prospecto
 JOIN contacto c ON c.id_contacto=pr.id_contacto WHERE p.id_propuesta=v_id_propuesta;
 UPDATE venta SET estado='Anulada' WHERE id_venta=p_id_venta;
 UPDATE prospecto SET estado='Contactado' WHERE id_prospecto=v_id_prospecto;
 IF v_id_empresa IS NOT NULL AND NOT EXISTS(
   SELECT 1 FROM venta v JOIN propuesta p ON p.id_propuesta=v.id_propuesta
   JOIN prospecto pr ON pr.id_prospecto=p.id_prospecto JOIN contacto c ON c.id_contacto=pr.id_contacto
   WHERE c.id_empresa=v_id_empresa AND v.estado='Cerrada'
 ) THEN UPDATE empresa SET estado='Prospecto' WHERE id_empresa=v_id_empresa; END IF;
END$$

DROP PROCEDURE IF EXISTS reporte_mensual$$
CREATE PROCEDURE reporte_mensual(IN p_mes DATE)
BEGIN
 DECLARE v_inicio DATE; DECLARE v_fin DATE;
 SET v_inicio=STR_TO_DATE(DATE_FORMAT(p_mes,'%Y-%m-01'),'%Y-%m-%d');
 SET v_fin=DATE_ADD(v_inicio,INTERVAL 1 MONTH);
 SELECT v_inicio AS mes,
   (SELECT COUNT(*) FROM contacto WHERE fecha_registro>=v_inicio AND fecha_registro<v_fin) AS contactos_nuevos,
   (SELECT COUNT(*) FROM descarga_prueba WHERE fecha_descarga>=v_inicio AND fecha_descarga<v_fin) AS descargas,
   (SELECT COUNT(*) FROM prospecto WHERE fecha_calificacion>=v_inicio AND fecha_calificacion<v_fin) AS calificados,
   (SELECT COUNT(*) FROM propuesta WHERE fecha_emision>=v_inicio AND fecha_emision<v_fin) AS propuestas,
   (SELECT COUNT(*) FROM venta WHERE fecha_cierre>=v_inicio AND fecha_cierre<v_fin AND estado='Cerrada') AS ventas,
   COALESCE((SELECT ROUND(100*SUM(estado='Calificado')/NULLIF(COUNT(*),0),2) FROM prospecto
     WHERE fecha_creacion>=v_inicio AND fecha_creacion<v_fin),0) AS conversion_calificados_pct;
END$$

DELIMITER ;

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

-- 04. TRANSACCIONES DE DEMOSTRACION
-- T1: crear propuesta. Savepoint revierte la segunda linea, preservando la primera.
START TRANSACTION;
INSERT INTO propuesta(id_prospecto,id_empleado,fecha_emision,fecha_vencimiento,descuento_pct,total,estado,observaciones)
SELECT id_prospecto,1,CURRENT_DATE,DATE_ADD(CURRENT_DATE,INTERVAL 30 DAY),5,0,'Borrador','Demo de savepoint'
FROM prospecto WHERE id_contacto=31 ORDER BY id_prospecto DESC LIMIT 1;
SET @id_propuesta_demo=LAST_INSERT_ID();
SAVEPOINT sp_cabecera;
INSERT INTO detalle_propuesta(id_propuesta,id_producto,cantidad,precio_unitario)
SELECT @id_propuesta_demo,id_producto,2,precio_unitario FROM producto WHERE id_producto=1;
SAVEPOINT sp_segunda_linea;
INSERT INTO detalle_propuesta(id_propuesta,id_producto,cantidad,precio_unitario)
SELECT @id_propuesta_demo,id_producto,1,precio_unitario FROM producto WHERE id_producto=2;
ROLLBACK TO SAVEPOINT sp_segunda_linea;
UPDATE propuesta SET estado='Enviada' WHERE id_propuesta=@id_propuesta_demo;
COMMIT;

-- T2: aceptar la propuesta y registrar la venta dentro de una transaccion ACID.
START TRANSACTION;
UPDATE propuesta SET estado='Aceptada' WHERE id_propuesta=@id_propuesta_demo AND estado='Enviada';
CALL generar_venta(@id_propuesta_demo,'Transferencia');
COMMIT;

-- T3: visita de retorno: el trigger de actividad genera una nueva alerta para el vendedor.
START TRANSACTION;
INSERT INTO actividad_web(id_contacto,tipo_actividad,url_pagina,puntos)
VALUES(32,'Visita','/precios',5);
COMMIT;

-- T4: reporte mensual.
CALL reporte_mensual(CURRENT_DATE);

-- Ejemplo para probar ROLLBACK total en una ejecucion aparte:
-- START TRANSACTION;
-- UPDATE producto SET precio_unitario=-1 WHERE id_producto=1; -- falla por CHECK
-- ROLLBACK;