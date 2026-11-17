import { CommonModule } from '@angular/common';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { ChangeDetectorRef, Component, OnInit } from '@angular/core';

interface Prospect {
  id_prospecto: number; puntaje: number; estado: string; contacto: string;
  apellido: string; email: string; empresa: string | null; vendedor: string | null;
}
interface AlertItem {
  id_alerta: number; id_prospecto: number; mensaje: string; contacto: string;
  email: string; fecha_hora: string; leida: boolean;
}
interface Metrics {
  contactos: number; prospectos_activos: number; propuestas: number;
  ventas: number; ingresos: number; alertas_pendientes: number;
}

@Component({
  selector: 'app-root', standalone: true, imports: [CommonModule],
  templateUrl: './app.component.html', styleUrl: './app.component.css'
})
export class AppComponent implements OnInit {
  private readonly api = window.location.port === '4200' ? 'http://127.0.0.1:8080/api' : '/api';
  metrics: Metrics | null = null;
  prospects: Prospect[] = [];
  alerts: AlertItem[] = [];
  loading = true;
  connection = false;
  message = '';
  busyId: number | null = null;

  constructor(private readonly http: HttpClient, private readonly changeDetector: ChangeDetectorRef) {}

  ngOnInit(): void { this.refresh(); }

  refresh(preserveMessage = false): void {
    this.loading = true;
    if (!preserveMessage) this.message = '';
    this.http.get<{connected: boolean}>(`${this.api}/health/db`).subscribe({
      next: (health) => { this.connection = health.connected; this.changeDetector.detectChanges(); this.loadPanels(preserveMessage); },
      error: () => { this.connection = false; this.loading = false; this.message = 'No se pudo conectar con Java o MySQL. Revisa que los servicios estén iniciados.'; this.changeDetector.detectChanges(); }
    });
  }

  private loadPanels(preserveMessage: boolean): void {
    this.http.get<Metrics>(`${this.api}/dashboard`).subscribe({ next: value => { this.metrics = value; this.changeDetector.detectChanges(); } });
    this.http.get<Prospect[]>(`${this.api}/prospects`).subscribe({ next: value => { this.prospects = value; this.changeDetector.detectChanges(); } });
    this.http.get<AlertItem[]>(`${this.api}/alerts`).subscribe({
      next: value => { this.alerts = value; this.loading = false; if (!preserveMessage) this.message = ''; this.changeDetector.detectChanges(); },
      error: (error: HttpErrorResponse) => { this.loading = false; this.message = error.message; this.changeDetector.detectChanges(); }
    });
  }

  simulateVisit(prospect: Prospect): void {
    this.busyId = prospect.id_prospecto;
    this.http.post(`${this.api}/prospects/${prospect.id_prospecto}/visit`, {}).subscribe({
      next: () => { this.message = `Visita de ${prospect.contacto} registrada. La alerta aparece para su vendedor.`; this.busyId = null; this.changeDetector.detectChanges(); this.refresh(true); },
      error: () => { this.message = 'No se pudo registrar la visita.'; this.busyId = null; this.changeDetector.detectChanges(); }
    });
  }

  markRead(alert: AlertItem): void {
    this.http.patch(`${this.api}/alerts/${alert.id_alerta}/read`, {}).subscribe({ next: () => this.refresh() });
  }

  money(value: number | undefined): string {
    return new Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', maximumFractionDigits: 0 }).format(value ?? 0);
  }
}
