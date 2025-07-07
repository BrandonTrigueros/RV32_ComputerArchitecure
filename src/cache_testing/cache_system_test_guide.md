# Guía de Prueba del Sistema de Caché Coherente MSI

## Parte 1: Configuración del Componente Top-Level

### 1.1 Abrir el Archivo Principal
1. Abre Logisim Evolution
2. Carga el archivo `32RV.circ`
3. Crea un nuevo circuito llamado `cache_system_test`

### 1.2 Instanciar el Componente TransactionsBetweenCPU
1. En el circuito `cache_system_test`, ve al menú de componentes
2. Busca el componente `TransactionsBetweenCPU` (aparece como `cache_system`)
3. Colócalo en el centro del circuito

### 1.3 Pines del Componente TransactionsBetweenCPU
El componente tiene los siguientes pines:

**Pines de Control:**
- `clk` (1 bit) - Reloj del sistema
- `rst` (1 bit) - Reset síncrono
- `cpu0_prio` (1 bit) - Prioridad de arbitraje para CPU0
- `cpu1_prio` (1 bit) - Prioridad de arbitraje para CPU1

**Interfaz CPU0:**
- `cpu0_wantedAddr` (3 bits) - Dirección objetivo CPU0
- `cpu0_data_in` (32 bits) - Datos de entrada CPU0
- `cpu0_data_out` (32 bits) - Datos de salida CPU0
- `cpu0_req` (1 bit) - Solicitud de operación CPU0
- `cpu0_rw` (1 bit) - Lectura/Escritura CPU0 (0=read, 1=write)
- `cpu0_ready` (1 bit) - Operación completa CPU0

**Interfaz CPU1:**
- `cpu1_wantedAddr` (3 bits) - Dirección objetivo CPU1
- `cpu1_data_in` (32 bits) - Datos de entrada CPU1
- `cpu1_data_out` (32 bits) - Datos de salida CPU1
- `cpu1_req` (1 bit) - Solicitud de operación CPU1
- `cpu1_rw` (1 bit) - Lectura/Escritura CPU1 (0=read, 1=write)
- `cpu1_ready` (1 bit) - Operación completa CPU1

## Parte 2: Creación del Circuito de Prueba

### 2.1 Componentes Necesarios
- 1 Clock (reloj del sistema)
- 1 Button (reset)
- 2 Constant/Input Pin (prioridades CPU0/CPU1)
- 6 Pin de entrada (direcciones y requests)
- 2 Pin de entrada 32-bit (datos de entrada)
- 2 Input Pin (operaciones read/write)
- 2 Pin de salida 32-bit (datos de salida)
- 2 LEDs (señales ready)

### 2.2 Layout del Circuito de Prueba

```
    [Clock]──────────────────────────────┐
    [Reset Button]───────────────────────┼─── [TransactionsBetweenCPU]
    [CPU0 Prio Input]───────────────────┤
    [CPU1 Prio Input]───────────────────┤
                                         │
    CPU0 Controls:                       │
    [Addr0 Input]────────────────────────┤
    [Data0 Input]────────────────────────┤
    [Req0 Input]─────────────────────────┤
    [RW0 Input]──────────────────────────┤
                                         │
    CPU1 Controls:                       │
    [Addr1 Input]────────────────────────┤
    [Data1 Input]────────────────────────┤
    [Req1 Input]─────────────────────────┤
    [RW1 Input]──────────────────────────┤
                                         │
    Outputs:                             │
    [Data0 Output]───────────────────────┤
    [Data1 Output]───────────────────────┤
    [Ready0 LED]─────────────────────────┤
    [Ready1 LED]─────────────────────────┘
```

### 2.3 Conexiones Detalladas

#### 2.3.1 Señales de Control
- **Clock**: Conecta un componente Clock a la entrada `clk`
- **Reset**: Conecta un Button a la entrada `rst`
- **Prioridades**: Conecta pines de entrada a `cpu0_prio` y `cpu1_prio`

#### 2.3.2 Interfaz CPU0
- **Dirección**: Pin de entrada de 3 bits → `cpu0_wantedAddr`
- **Datos entrada**: Pin de entrada de 32 bits → `cpu0_data_in`
- **Request**: Pin de entrada → `cpu0_req`
- **Read/Write**: Pin de entrada → `cpu0_rw`
- **Datos salida**: `cpu0_data_out` → Pin de salida de 32 bits
- **Ready**: `cpu0_ready` → LED

#### 2.3.3 Interfaz CPU1
- **Dirección**: Pin de entrada de 3 bits → `cpu1_wantedAddr`
- **Datos entrada**: Pin de entrada de 32 bits → `cpu1_data_in`
- **Request**: Pin de entrada → `cpu1_req`
- **Read/Write**: Pin de entrada → `cpu1_rw`
- **Datos salida**: `cpu1_data_out` → Pin de salida de 32 bits
- **Ready**: `cpu1_ready` → LED

## Parte 3: Casos de Prueba

### 3.1 Prueba Básica - Lectura Simple
**Objetivo**: Verificar que cada CPU puede leer datos independientemente

1. **Configuración inicial**:
   - Reset = 1 (por un ciclo)
   - cpu0_prio = 1, cpu1_prio = 0
   - cpu0_req = 0, cpu1_req = 0

2. **Operación CPU0**:
   - cpu0_wantedAddr = 0x1
   - cpu0_rw = 0 (read)
   - cpu0_req = 1
   - Esperar hasta que cpu0_ready = 1
   - Verificar cpu0_data_out = 0x11111111

3. **Operación CPU1**:
   - cpu1_wantedAddr = 0x2
   - cpu1_rw = 0 (read)
   - cpu1_req = 1
   - Esperar hasta que cpu1_ready = 1
   - Verificar cpu1_data_out = 0x22222222

### 3.2 Prueba de Coherencia - Compartir Datos
**Objetivo**: Verificar el protocolo MSI para lecturas compartidas

1. **CPU0 lee dirección 0x3**:
   - cpu0_wantedAddr = 0x3
   - cpu0_rw = 0, cpu0_req = 1
   - Esperar cpu0_ready = 1
   - Estado esperado: CPU0 tiene línea en SHARED

2. **CPU1 lee la misma dirección 0x3**:
   - cpu1_wantedAddr = 0x3
   - cpu1_rw = 0, cpu1_req = 1
   - Esperar cpu1_ready = 1
   - Estado esperado: Ambas CPUs tienen línea en SHARED

### 3.3 Prueba de Coherencia - Escritura con Invalidación
**Objetivo**: Verificar invalidación cuando una CPU escribe datos compartidos

1. **Ambas CPUs leen dirección 0x4** (como en prueba 3.2)
2. **CPU0 escribe en dirección 0x4**:
   - cpu0_wantedAddr = 0x4
   - cpu0_data_in = 0xAAAAAAAA
   - cpu0_rw = 1, cpu0_req = 1
   - Esperar cpu0_ready = 1
   - Estado esperado: CPU0 en MODIFIED, CPU1 invalidada

3. **CPU1 intenta leer dirección 0x4**:
   - cpu1_wantedAddr = 0x4
   - cpu1_rw = 0, cpu1_req = 1
   - Esperar cpu1_ready = 1
   - Verificar cpu1_data_out = 0xAAAAAAAA
   - Estado esperado: Ambas CPUs en SHARED

### 3.4 Prueba de Evicción
**Objetivo**: Verificar que las líneas modificadas se escriben a memoria

1. **Llenar la caché CPU0** (4 líneas):
   - Leer direcciones 0x0, 0x1, 0x2, 0x3
   - Escribir en dirección 0x3 (valor 0xBBBBBBBB)

2. **Forzar evicción**:
   - Leer dirección 0x4
   - Esto debería evictar la línea más antigua y hacer writeback si está MODIFIED

3. **Verificar writeback**:
   - CPU1 lee dirección 0x3
   - Verificar que obtiene 0xBBBBBBBB (el valor escrito por CPU0)

### 3.5 Prueba de Acceso Concurrente
**Objetivo**: Verificar arbitraje y acceso simultáneo

1. **Configurar prioridades**:
   - cpu0_prio = 1, cpu1_prio = 0

2. **Solicitudes simultáneas**:
   - cpu0_wantedAddr = 0x5, cpu0_rw = 0, cpu0_req = 1
   - cpu1_wantedAddr = 0x6, cpu1_rw = 0, cpu1_req = 1
   - Activar ambas en el mismo ciclo

3. **Verificar orden de procesamiento**:
   - CPU0 debería completarse primero (mayor prioridad)
   - CPU1 debería completarse después

## Parte 4: Patrones de Prueba Automatizados

### 4.1 Secuencia de Inicialización
```
Ciclo 1: rst=1, todo lo demás=0
Ciclo 2: rst=0, configurar primera prueba
```

### 4.2 Patron de Lectura
```
Ciclo N:   addr=X, rw=0, req=1
Ciclo N+1: req=0, esperar ready=1
Ciclo N+2: verificar valor en data_out
```

### 4.3 Patron de Escritura
```
Ciclo N:   addr=X, data_in=Y, rw=1, req=1
Ciclo N+1: req=0, esperar ready=1
Ciclo N+2: operación completa
```

## Parte 5: Valores de Referencia

### 5.1 Contenido Inicial de SDRAM
```
Dirección 0x0: 0x00000000
Dirección 0x1: 0x11111111
Dirección 0x2: 0x22222222
Dirección 0x3: 0x33333333
Dirección 0x4: 0x44444444
Dirección 0x5: 0x55555555
Dirección 0x6: 0x66666666
Dirección 0x7: 0x77777777
```

### 5.2 Estados MSI Esperados
- **INVALID**: Línea no válida/no presente
- **SHARED**: Línea válida, posiblemente en otras cachés
- **MODIFIED**: Línea válida, modificada localmente, única copia

## Parte 6: Troubleshooting

### 6.1 Problemas Comunes
- **ready nunca se activa**: Verificar señales de clock y reset
- **Datos incorrectos**: Verificar direcciones y secuencia de operaciones
- **Coherencia fallida**: Verificar protocolo MSI y señales cache-to-cache

### 6.2 Señales de Debug
- Monitorear LEDs de ready para timing
- Observar valores directamente en los pines de salida
- Verificar secuencia de operaciones paso a paso
