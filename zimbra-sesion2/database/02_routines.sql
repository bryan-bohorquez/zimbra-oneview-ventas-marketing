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
