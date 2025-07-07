# Guía de Debug del Cache Controller

## Descripción General

Se han añadido múltiples salidas de debug al controlador de caché (`Cache_Controller`) para facilitar la monitorización y depuración del estado interno del controlador durante la simulación.

## Nuevas Señales de Debug Añadidas

### 1. Estado del Controlador de CPU
- **`debug_cpu_state`** (3 bits): Estado actual de la máquina de estados de la CPU
  - `000`: CPU_IDLE - CPU inactiva
  - `001`: CPU_READ - Procesando operación de lectura
  - `010`: CPU_WRITE - Procesando operación de escritura
  - `011`: CPU_WAIT_CACHE - Esperando respuesta de caché
  - `100`: CPU_WAIT_SDRAM - Esperando respuesta de SDRAM
  - `111`: Estado desconocido

### 2. Estado del Controlador de Caché
- **`debug_cache_state`** (3 bits): Estado actual de la máquina de estados de la caché
  - `000`: CACHE_CHECK - Verificando hit/miss
  - `001`: CACHE_HIT - Cache hit detectado
  - `010`: CACHE_MISS - Cache miss detectado
  - `011`: CACHE_COHERENCE - Realizando transferencia cache-to-cache
  - `100`: CACHE_SDRAM_ACCESS - Accediendo a SDRAM
  - `111`: Estado desconocido

### 3. Información de Operación Actual
- **`debug_cache_hit`** (1 bit): Indica si la operación actual es un cache hit
- **`debug_current_addr`** (3 bits): Dirección que está siendo procesada actualmente
- **`debug_operation_type`** (1 bit): Tipo de operación actual
  - `0`: Operación de lectura (READ)
  - `1`: Operación de escritura (WRITE)

### 4. Información de Control Interno
- **`debug_evict_index`** (2 bits): Índice de la línea que será evictada en caso de reemplazo
- **`debug_cycle_counter`** (4 bits): Contador de ciclos interno para control de timing

### 5. Estado de las Líneas de Caché (4 líneas: 0-3)

Para cada línea de caché (0, 1, 2, 3) se proporcionan las siguientes señales:

- **`debug_cache_lineX_valid`** (1 bit): Indica si la línea X es válida
- **`debug_cache_lineX_state`** (2 bits): Estado MSI de la línea X
  - `00`: MSI_INVALID - Línea inválida
  - `01`: MSI_SHARED - Línea compartida (datos limpios)
  - `10`: MSI_MODIFIED - Línea modificada (datos sucios)
  - `11`: Estado desconocido
- **`debug_cache_lineX_addr`** (3 bits): Dirección almacenada en la línea X
- **`debug_cache_lineX_data`** (32 bits): Datos almacenados en la línea X

## Cómo Usar las Señales de Debug

### 1. En Logisim Evolution

1. **Conectar LEDs para estados discretos:**
   ```
   debug_cpu_state[2:0] → Display hexadecimal de 7 segmentos
   debug_cache_state[2:0] → Display hexadecimal de 7 segmentos
   debug_cache_hit → LED simple
   debug_operation_type → LED simple
   ```

2. **Conectar displays para datos numéricos:**
   ```
   debug_current_addr[2:0] → Display hexadecimal
   debug_evict_index[1:0] → Display hexadecimal
   debug_cycle_counter[3:0] → Display hexadecimal
   ```

3. **Monitorear líneas de caché:**
   ```
   debug_cache_line0_valid → LED
   debug_cache_line0_state[1:0] → Display hexadecimal
   debug_cache_line0_addr[2:0] → Display hexadecimal
   debug_cache_line0_data[31:0] → Display hexadecimal de 32 bits
   ```

### 2. Ejemplo de Configuración de Test

```vhdl
-- Instanciar el Cache_Controller con debug outputs
Cache_Controller_instance: Cache_Controller
port map (
    clk => clk,
    reset => reset,
    -- ... puertos normales ...
    
    -- Conectar señales de debug
    debug_cpu_state => cpu_state_display,
    debug_cache_state => cache_state_display,
    debug_cache_hit => hit_led,
    debug_current_addr => current_addr_display,
    debug_operation_type => operation_led,
    debug_evict_index => evict_display,
    debug_cycle_counter => cycle_display,
    
    -- Estados de líneas de caché
    debug_cache_line0_valid => line0_valid_led,
    debug_cache_line0_state => line0_state_display,
    debug_cache_line0_addr => line0_addr_display,
    debug_cache_line0_data => line0_data_display,
    -- ... repetir para líneas 1, 2, 3 ...
);
```

## Escenarios de Debug Típicos

### 1. Verificar Cache Hits/Misses
- Monitorear `debug_cache_hit` junto con `debug_current_addr`
- Observar transiciones en `debug_cache_state` de CACHE_CHECK → CACHE_HIT/CACHE_MISS

### 2. Seguir el Protocolo MSI
- Observar `debug_cache_lineX_state` para ver transiciones MSI
- Monitorear cuando las líneas cambian de INVALID → SHARED → MODIFIED

### 3. Debugging de Coherencia
- Verificar `debug_cache_state` cuando está en CACHE_COHERENCE
- Observar transferencias cache-to-cache en las señales normales del protocolo

### 4. Análisis de Rendimiento
- Usar `debug_cycle_counter` para medir timing
- Observar frecuencia de transiciones entre estados de CPU

## Interpretación de Estados Comunes

### Secuencia Normal de Lectura (Cache Miss):
1. `debug_cpu_state = 001` (CPU_READ)
2. `debug_cache_state = 000` (CACHE_CHECK)
3. `debug_cache_hit = 0`
4. `debug_cache_state = 010` (CACHE_MISS)
5. `debug_cache_state = 011` (CACHE_COHERENCE)
6. `debug_cache_state = 100` (CACHE_SDRAM_ACCESS)
7. `debug_cpu_state = 000` (CPU_IDLE)

### Secuencia Normal de Escritura (Cache Hit):
1. `debug_cpu_state = 010` (CPU_WRITE)
2. `debug_cache_state = 000` (CACHE_CHECK)
3. `debug_cache_hit = 1`
4. `debug_cache_state = 001` (CACHE_HIT)
5. `debug_cache_lineX_state = 10` (MSI_MODIFIED)
6. `debug_cpu_state = 000` (CPU_IDLE)

## Consejos de Uso

1. **Usa displays hexadecimales** para visualizar mejor los estados de 2-3 bits
2. **Conecta todas las líneas de caché** para obtener una vista completa del estado
3. **Observa las transiciones** más que los valores estáticos
4. **Combina señales de debug** con las señales normales del protocolo para debugging completo
5. **Usa el cycle_counter** para correlacionar eventos temporalmente

## Limitaciones

- Las señales de debug están sincronizadas con el reloj
- Algunos estados intermedios pueden ser muy rápidos para observar manualmente
- Para análisis detallado, considera usar las funciones de traza de Logisim Evolution
