package edu.uniminuto.zimbra;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = {"http://localhost:4200", "http://127.0.0.1:4200"})
public class ZimbraController {
    private final JdbcTemplate jdbc;

    public ZimbraController(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    @GetMapping("/health/db")
    public Map<String, Object> databaseHealth() {
        Integer result = jdbc.queryForObject("SELECT 1", Integer.class);
        return Map.of("connected", result != null && result == 1, "database", "MySQL", "service", "zimbra-api");
    }

    @GetMapping("/dashboard")
    public Map<String, Object> dashboard() {
        return jdbc.queryForMap("""
            SELECT (SELECT COUNT(*) FROM contacto) contactos,
                   (SELECT COUNT(*) FROM prospecto WHERE estado IN ('Calificado','Contactado','Propuesta enviada')) prospectos_activos,
                   (SELECT COUNT(*) FROM propuesta) propuestas,
                   (SELECT COUNT(*) FROM venta WHERE estado='Cerrada') ventas,
                   (SELECT COALESCE(SUM(monto_total),0) FROM venta WHERE estado='Cerrada') ingresos,
                   (SELECT COUNT(*) FROM alerta WHERE leida=FALSE) alertas_pendientes
            """);
    }

    @GetMapping("/prospects")
    public List<Map<String, Object>> prospects() {
        return jdbc.queryForList("""
            SELECT p.id_prospecto, p.puntaje, p.estado, p.fecha_creacion,
                   c.nombre contacto, c.apellido, c.email,
                   e.razon_social empresa,
                   CONCAT(v.nombre,' ',v.apellido) vendedor
            FROM prospecto p JOIN contacto c ON c.id_contacto=p.id_contacto
            LEFT JOIN empresa e ON e.id_empresa=c.id_empresa
            LEFT JOIN empleado v ON v.id_empleado=p.id_vendedor
            ORDER BY FIELD(p.estado,'Calificado','Contactado','Propuesta enviada','Nuevo','Ganado','Perdido'), p.puntaje DESC
            LIMIT 100
            """);
    }

    @GetMapping("/alerts")
    public List<Map<String, Object>> alerts(@RequestParam(defaultValue = "true") boolean unreadOnly) {
        String sql = """
            SELECT a.id_alerta,a.id_prospecto,a.mensaje,a.fecha_hora,a.leida,
                   CONCAT(c.nombre,' ',c.apellido) contacto, c.email,
                   CONCAT(e.nombre,' ',e.apellido) vendedor
            FROM alerta a JOIN prospecto p ON p.id_prospecto=a.id_prospecto
            JOIN contacto c ON c.id_contacto=p.id_contacto
            JOIN empleado e ON e.id_empleado=a.id_vendedor
            """ + (unreadOnly ? " WHERE a.leida=FALSE" : "") + " ORDER BY a.fecha_hora DESC LIMIT 50";
        return jdbc.queryForList(sql);
    }

    @PostMapping("/prospects/{id}/visit")
    @Transactional
    public Map<String, Object> recordReturnVisit(@PathVariable long id) {
        Long contactId;
        try {
            contactId = jdbc.queryForObject("SELECT id_contacto FROM prospecto WHERE id_prospecto=?", Long.class, id);
        } catch (EmptyResultDataAccessException ex) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró el prospecto.");
        }
        jdbc.update("INSERT INTO actividad_web(id_contacto,tipo_actividad,url_pagina,puntos) VALUES(?,?,?,?)",
                contactId, "Visita", "/precios", 5);
        return Map.of("registrada", true, "prospectoId", id,
                "mensaje", "Visita registrada. Si está calificado y tiene vendedor, se crea una alerta.");
    }

    @PatchMapping("/alerts/{id}/read")
    public Map<String, Object> markAlertRead(@PathVariable long id) {
        int changed = jdbc.update("UPDATE alerta SET leida=TRUE WHERE id_alerta=?", id);
        if (changed == 0) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la alerta.");
        return Map.of("actualizada", true, "id", id);
    }

    @PostMapping("/proposals/{id}/sale")
    @Transactional
    public Map<String, Object> closeSale(@PathVariable long id,
            @RequestParam(defaultValue = "Transferencia") String formaPago) {
        try {
            jdbc.update("CALL generar_venta(?,?)", id, formaPago);
            return Map.of("registrada", true, "propuestaId", id, "mensaje", "Venta registrada en una transacción.");
        } catch (RuntimeException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "No se pudo cerrar la venta: " + ex.getMessage());
        }
    }

    @GetMapping("/reports/monthly")
    public Map<String, Object> monthlyReport(@RequestParam String month) {
        Date monthDate = Date.valueOf(month + "-01");
        return jdbc.execute((ConnectionCallback<Map<String, Object>>) connection -> {
            try (CallableStatement call = connection.prepareCall("{CALL reporte_mensual(?)}")) {
                call.setDate(1, monthDate);
                boolean hasResults = call.execute();
                while (hasResults || call.getUpdateCount() != -1) {
                    if (hasResults) {
                        try (var rs = call.getResultSet()) {
                            if (rs != null && rs.next()) {
                                Map<String, Object> row = new HashMap<>();
                                row.put("mes", rs.getDate("mes"));
                                row.put("contactos_nuevos", rs.getLong("contactos_nuevos"));
                                row.put("descargas", rs.getLong("descargas"));
                                row.put("calificados", rs.getLong("calificados"));
                                row.put("propuestas", rs.getLong("propuestas"));
                                row.put("ventas", rs.getLong("ventas"));
                                row.put("conversion_calificados_pct", rs.getBigDecimal("conversion_calificados_pct"));
                                return row;
                            }
                        }
                    }
                    hasResults = call.getMoreResults();
                }
                return Map.of("mes", month, "mensaje", "El procedimiento no retornó filas.");
            }
        });
    }
}
