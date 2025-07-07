# Guía de Diagnóstico y Solución de Problemas del Sistema Cache

## Problemas Identificados y Corregidos

### 1. `cpu0_ready` nunca se activa durante lecturas

**Problema**: El controlador de caché no completaba correctamente las operaciones de lectura debido a problemas en el flujo de la máquina de estados.

**Causa raíz**: 
- En el estado `CACHE_COHERENCE`, después de una transferencia cache-to-cache exitosa, el código volvía prematuramente a `CACHE_CHECK` antes de completar la asignación de datos.
- En el estado `CACHE_SDRAM_ACCESS`, el controlador intentaba leer del SDRAM y asignar la línea de caché en el mismo ciclo, sin esperar la respuesta del SDRAM.

**Solución aplicada**:
1. **Flujo Cache-to-Cache**: Eliminé la transición prematura a `CACHE_CHECK` en el estado `CACHE_COHERENCE`.
2. **Acceso SDRAM**: Separé el acceso al SDRAM en dos estados:
   - `CACHE_SDRAM_ACCESS`: Envía la solicitud al SDRAM
   - `CACHE_SDRAM_WAIT`: Espera y procesa la respuesta del SDRAM
3. **Señal de control**: Agregué `sdram_request_pending` para rastrear solicitudes pendientes al SDRAM.

### 2. Flujo de Estados Corregido

**Secuencia para Cache Miss con lectura**:
1. `CPU_IDLE` → `CPU_READ` (cuando cpu_req = '1')
2. `CACHE_CHECK` → `CACHE_MISS` (no hay hit)
3. `CACHE_MISS` → `CACHE_COHERENCE` (intenta cache-to-cache)
4. `CACHE_COHERENCE` → `CACHE_SDRAM_ACCESS` (si cache-to-cache falla)
5. `CACHE_SDRAM_ACCESS` → `CACHE_SDRAM_WAIT` (espera respuesta SDRAM)
6. `CACHE_SDRAM_WAIT` → `CPU_IDLE` (operación completa, cpu_ready = '1')

## Cómo Verificar que el Problema está Resuelto

### Test Básico de Lectura
1. **Configuración inicial**:
   - `cpu0_req = '1'`
   - `cpu0_rw = '0'` (lectura)
   - `cpu0_wantedAddr = "001"` (dirección 1)
   - `cpu0_prio = '1'`
   - `cpu1_req = '0'`

2. **Secuencia esperada**:
   - **Ciclo 1**: Sistema recibe solicitud, transición a `CPU_READ`
   - **Ciclo 2**: `CACHE_CHECK` → `CACHE_MISS` (caché vacío)
   - **Ciclo 3**: `CACHE_MISS` → `CACHE_COHERENCE` (intenta cache-to-cache)
   - **Ciclo 4**: `CACHE_COHERENCE` → `CACHE_SDRAM_ACCESS` (no hay respuesta de otro caché)
   - **Ciclo 5**: `CACHE_SDRAM_ACCESS` → `CACHE_SDRAM_WAIT` (solicitud enviada al SDRAM)
   - **Ciclo 6**: `CACHE_SDRAM_WAIT` → `CPU_IDLE` con `cpu0_ready = '1'` y `cpu0_data_out = 0x11111111`

### Monitoreo en Logisim
Para verificar que el sistema funciona correctamente:

1. **Señales internas a observar**:
   - `cpu_state` en Cache_Controller
   - `cache_state` en Cache_Controller
   - `sdram_request_pending` (nueva señal)
   - `read_en` y `write_en` hacia SDRAM
   - `ready1_sig` (señal combinada hacia SDRAM)

2. **Indicadores de funcionamiento correcto**:
   - `cpu0_ready` se activa después de 5-6 ciclos de reloj
   - `cpu0_data_out` muestra el valor leído del SDRAM
   - Las señales `read_en` y `write_en` se activan correctamente
   - No hay estados colgados o bucles infinitos

## Problemas Adicionales Posibles

### 1. Señales de Control no Conectadas
**Síntoma**: El sistema no responde a ninguna entrada.
**Solución**: Verificar que todas las señales de entrada estén conectadas correctamente en Logisim.

### 2. Reset no Funciona
**Síntoma**: El sistema no se inicializa correctamente.
**Solución**: Asegurar que la señal `rst` esté conectada y sea '1' durante al menos un ciclo al inicio.

### 3. Clock no Funciona
**Síntoma**: Nada cambia en el sistema.
**Solución**: Verificar que el componente Clock esté configurado correctamente y conectado a la entrada `clk`.

### 4. Datos Incorrectos del SDRAM
**Síntoma**: `cpu0_data_out` muestra valores incorrectos.
**Solución**: Verificar la inicialización del SDRAM en el código VHDL. Los valores iniciales son:
- Dirección 0: 0x00000000
- Dirección 1: 0x11111111
- Dirección 2: 0x22222222
- etc.

## Próximos Pasos para Pruebas

1. **Prueba básica de lectura** (como se describe arriba)
2. **Prueba de escritura**: Cambiar `cpu0_rw = '1'` y proporcionar `cpu0_data_in`
3. **Prueba de coherencia**: Activar ambos CPUs simultáneamente
4. **Prueba de evicción**: Llenar el caché y forzar reemplazo de líneas

## Cambios en el Código

Los cambios principales realizados en el archivo `32RV.circ`:

1. **Nuevo estado**: `CACHE_SDRAM_WAIT` agregado al tipo `cache_state_type`
2. **Nueva señal**: `sdram_request_pending` para control de flujo
3. **Lógica de SDRAM**: Separada en dos ciclos para manejo correcto del timing
4. **Flujo cache-to-cache**: Eliminada transición prematura que causaba problemas

El sistema ahora debe funcionar correctamente para operaciones básicas de lectura y escritura.
