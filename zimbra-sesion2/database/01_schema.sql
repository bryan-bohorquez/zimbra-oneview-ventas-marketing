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
