# Zimbra OneView: implementacion de la Sesion 2

Prototipo transaccional de ventas y marketing para el caso Zimbra. La solucion usa **MySQL 8.0.16 o superior**, **Java 17 o posterior con Spring Boot 4** y **Angular 21**. El modelo conserva las 13 tablas del DMR y agrega `alerta` para registrar cada regreso al sitio de un prospecto calificado.

## Estructura

- `database/01_schema.sql`: base `zimbra_db` y 14 tablas con PK, FK, restricciones e indices.
- `database/02_routines.sql`: triggers de calificacion, alertas, totales y estados; procedimientos de venta, anulacion y reporte mensual.
- `database/03_seed.sql`: datos simulados, al menos 30 filas por tabla.
- `database/04_transactions_demo.sql`: ejemplo de transacciones y savepoints para ejecutar por bloques.
- `database/zimbra_oneview_completo.sql`: script integral; incluye tablas, rutinas, datos, savepoints, venta transaccional y reporte mensual.
- `backend/`: API REST Spring Boot con conexion JDBC a MySQL.
- `frontend/`: interfaz Angular para tablero, lista de prospectos y alertas.
- `docs/`: evidencias y documento academico.

## Dónde va cada código y cómo ejecutarlo desde VS Code

Abre la carpeta raíz `zimbra-sesion2` en VS Code con **Archivo > Abrir carpeta**. Cada tecnología tiene su propia carpeta; no pegues el código de todas en un solo archivo.

| Parte | Archivos |
|---|---|
| MySQL | `database/zimbra_oneview_completo.sql`; ábrelo en Workbench y ejecútalo una sola vez sobre una base vacía. |
| Java | `backend/src/main/java/edu/uniminuto/zimbra/`; la clase principal es `ZimbraApiApplication.java` y la API está en `ZimbraController.java`. |
| Conexión Java–MySQL | `backend/src/main/resources/application.properties`. |
| Angular | `frontend/src/app/app.component.html` (página), `app.component.ts` (lógica y llamadas a la API) y `app.component.css` (estilos). |

## Preparar la base de datos

1. Instala MySQL Server 8.0.16+ y abre MySQL Workbench.
2. Ejecuta el archivo completo `database/zimbra_oneview_completo.sql`. Como alternativa, ejecuta `01_schema.sql`, `02_routines.sql` y `03_seed.sql` en ese orden.
3. Comprueba que el script reporte al menos 30 filas en cada tabla. `actividad_web` contiene 60, `prospecto` contiene 60 y `alerta` se crea con el trigger de visitas de prospectos calificados.
4. Crea el usuario de la aplicacion con privilegios limitados. Ejecuta como administrador:

```sql
CREATE USER IF NOT EXISTS 'zimbra_app'@'localhost' IDENTIFIED BY 'cambia-esta-clave';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON zimbra_db.* TO 'zimbra_app'@'localhost';
FLUSH PRIVILEGES;
```

No se configura el navegador para conectarse directamente a MySQL: todas las consultas pasan por la API Java.

## Ejecutar en desarrollo

Después de cargar el esquema y los datos de prueba, abre dos terminales en VS Code.

En la primera, inicia el backend:

```powershell
cd backend
$env:DB_URL = 'jdbc:mysql://localhost:3306/zimbra_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=America/Bogota'
$env:DB_USER = 'zimbra_app'
$env:DB_PASSWORD = Read-Host 'Contraseña de MySQL para zimbra_app'
mvn spring-boot:run
```

En la segunda, inicia Angular:

```powershell
cd frontend
npm install
npm start
```

Abre `http://localhost:4200`. Angular consulta la API Java en `http://localhost:8080`. No publiques contraseñas reales en el repositorio; configura cada contraseña localmente en la terminal.

El backend requiere JDK 17 o posterior y Maven 3.9 o posterior. Para comprobar su conexión a MySQL, abre `http://localhost:8080/api/health/db`; debe responder `connected: true`.

### Rutas principales

| Metodo | Ruta | Funcion |
|---|---|---|
| GET | `/api/health/db` | Comprueba la conexion JDBC |
| GET | `/api/dashboard` | Resume contactos, prospectos, ventas e ingresos |
| GET | `/api/prospects` | Lista prospectos, estado, puntaje y vendedor |
| GET | `/api/alerts` | Lista alertas pendientes por retorno al sitio |
| POST | `/api/prospects/{id}/visit` | Registra la visita; el trigger puede crear una alerta |
| PATCH | `/api/alerts/{id}/read` | Marca una alerta como leida |
| POST | `/api/proposals/{id}/sale` | Llama al procedimiento de venta dentro de una transaccion |
| GET | `/api/reports/monthly?month=2026-11` | Ejecuta el procedimiento del reporte mensual |

## Transacciones ACID y savepoints

- `POST /api/prospects/{id}/visit` y `POST /api/proposals/{id}/sale` se ejecutan con `@Transactional` en Spring.
- `generar_venta` bloquea la propuesta (`SELECT ... FOR UPDATE`), inserta una sola venta por propuesta y actualiza el prospecto, la empresa y las pruebas activas. La llave `UNIQUE` de venta impide duplicados.
- `trg_actividad_procesar` incrementa el puntaje, califica al llegar a 50 puntos y genera la alerta para el vendedor en cada visita que cumpla la regla.
- `trg_propuesta_estado_bu` impide cambios de estado fuera del flujo permitido.
- `trg_detalle_total_*` recalcula el total de la propuesta cuando cambian sus lineas.
- `reporte_mensual` consolida los indicadores del mes recibido.
- El script integral demuestra una recuperacion con `ROLLBACK TO SAVEPOINT` y confirma la venta con `COMMIT`. Para observar un error de restriccion y hacer `ROLLBACK` total, sigue el bloque comentado en `04_transactions_demo.sql` y ejecutalo aparte.

## Datos academicos de prueba

Los correos y empresas de los scripts son ficticios. Los `password_hash` incluidos son marcadores de demostracion, no claves utilizables. No se envia correo real ni se conecta a Salesforce.com; el prototipo modela la actividad y conserva el punto de integracion en el modelo.

## Responsables propuestos

Se sigue la distribucion que el grupo incluyo en el plan de la Sesion 1. Andres asume la seleccion del motor y el esquema; Kamel, los datos y el backend; Bryan, transacciones, triggers, procedimientos y demostracion de errores. Las historias completas con criterios de aceptacion y responsable se agregan al informe APA de la Sesion 2.
