# StockFlow: backlog del MVP

App de inventario offline en Flutter. Este documento contiene el backlog, las decisiones técnicas y la definición de terminado.

**Ajuste de una regla.** Con la regla de borrado (solo se elimina un producto sin historial), un producto creado con stock inicial ya tendría un movimiento y nunca se podría eliminar, ni siquiera tras un error de captura. Por eso el movimiento "stock inicial" **no cuenta** como historial: un producto cuyo único movimiento sea ese se puede eliminar, y ambos se borran en una sola transacción.

## Backlog

| ID | Prioridad | Tarea | Resultado / criterios de aceptación | Dependencias |
|---|---|---|---|---|
| **E0 · Configuración** | | | | |
| S1 | MVP | Crear proyecto Flutter y repositorio | Proyecto solo Android (iOS opcional). `.gitignore` y `flutter_lints` activos. `flutter run` abre la app en un dispositivo. Primer commit en GitHub. | — |
| S2 | MVP | Dependencias y carpetas | Se añaden `flutter_riverpod`, `drift`, `drift_flutter` e `intl` (más `drift_dev` y `build_runner` en dev). Carpetas `core/` y `features/{products,movements,dashboard}`. App envuelta en `ProviderScope`. `pub get` y `build_runner` sin errores. | S1 |
| S3 | MVP | Shell de navegación | `MaterialApp` en español con `NavigationBar` de 3 pestañas (Dashboard, Productos, Movimientos) con pantallas vacías. Cambiar de pestaña conserva el estado. Navegación con `Navigator` nativo. | S2 |
| **E1 · Modelo de datos** | | | | |
| D1 | MVP | Tablas Drift | `products`: id, sku (UNIQUE), nombre, descripción null, precio_centavos null, stock, stock_minimo. `stock_movements`: id, product_id (FK), tipo, motivo, cantidad, fecha. CHECK: stock ≥ 0, stock_minimo ≥ 0, precio ≥ 0, cantidad > 0. Código generado sin errores. | S2 |
| D2 | MVP | Enums de tipo y motivo | Tipo: entrada/salida. Motivos fijos. Entrada: stock inicial (solo sistema), compra, devolución, ajuste. Salida: venta, merma, ajuste. Cada motivo pertenece a un solo tipo. Test de esa correspondencia. | D1 |
| D3 | MVP | Base de datos y provider | `AppDatabase` con archivo en el dispositivo y constructor en memoria para tests. Test de humo: inserta y lee un producto en memoria. | D1 |
| **E2 · Lógica de inventario** | | | | |
| L1 | MVP | Crear producto | Normaliza el SKU (trim y mayúsculas). Valida nombre no vacío y números ≥ 0. Si stock inicial > 0, inserta el movimiento "stock inicial" en la misma transacción. SKU duplicado lanza `DuplicateSkuException`. Tests: con y sin stock inicial, `" ab-1 "` equivale a `AB-1`, duplicado rechazado y sin datos a medias. | D2, D3 |
| L2 | MVP | Editar producto | Edita SKU, nombre, descripción, precio y stock mínimo, pero nunca el stock. Conservar su propio SKU es válido. Usar el SKU de otro producto falla. Tests de ambos casos y de que el stock no cambia. | L1 |
| L3 | MVP | Registrar movimiento | En una transacción: valida cantidad entera > 0 y motivo compatible con el tipo, inserta el movimiento y actualiza el stock. Salida mayor que el stock lanza `InsufficientStockException` sin cambios. Tests: entrada suma, salida resta, salida hasta 0 válida, rechazo sin modificar nada, y producto inexistente que revierte todo. | L1 |
| L4 | MVP | Eliminar producto | Permitido si no tiene movimientos o solo el de stock inicial (se borra junto con el producto). Con otros movimientos lanza `ProductHasMovementsException`. Tests de los tres casos. | L3 |
| L5 | MVP | Consultas reactivas | Streams de productos (orden por nombre), de movimientos (descendente, con nombre y SKU, filtro opcional por producto) y del dashboard. Dashboard: total de productos, stock bajo (`stock ≤ mínimo`, incluido el igual), y valor = Σ stock × precio solo de productos con precio. Tests: caso límite de stock bajo, valor ignora productos sin precio, y filtro por producto. | L3 |
| L6 | MVP | Providers de Riverpod | Providers para la base de datos, los repositorios y los `StreamProvider` de L5, sin generación de código. Se pueden sobrescribir en tests. | L5 |
| **E3 · Productos (UI)** | | | | |
| P1 | MVP | Lista de productos | Muestra nombre, SKU, stock e indicador de stock bajo, con estado vacío. Se actualiza en vivo y el tap abre el detalle. Widget test: items e indicador. | L6, S3 |
| P2 | MVP | Formulario crear/editar | Validaciones en español. Stock inicial solo al crear. Precio decimal convertido a centavos. El error de SKU duplicado se muestra bajo el campo. Widget test: datos inválidos no guardan. | L1, L2, P1 |
| P3 | MVP | Detalle de producto | Muestra datos, stock y botones Entrada, Salida, Editar y Eliminar. Eliminar pide confirmación y, si está bloqueado, explica por qué. Incluye últimos movimientos del producto. | L4, P2 |
| **E4 · Movimientos (UI)** | | | | |
| M1 | MVP | Formulario de movimiento | El tipo viene del botón pulsado. Cantidad entera > 0 y motivo filtrado por tipo. Una salida excesiva muestra "Stock disponible: N" y no guarda. Tras guardar, el stock se ve actualizado. Widget test del bloqueo. | L3, P3 |
| M2 | MVP | Historial | Lista descendente con producto, tipo, cantidad con signo, motivo y fecha. Filtro por producto y estado vacío. | L5, S3 |
| **E5 · Dashboard** | | | | |
| H1 | MVP | Pantalla de dashboard | Tarjetas de total de productos, productos con stock bajo y valor del inventario (indica que excluye productos sin precio). Lista de stock bajo con tap al detalle. Widget test con providers sobrescritos. | L5, P3 |
| **E6 · Validación final** | | | | |
| V1 | MVP | Prueba manual en dispositivo | Checklist: crear producto, entrada, salida, bloqueo de salida excesiva, eliminar con y sin historial. Cerrar y reabrir la app conserva los datos. Funciona en modo avión. | H1, M2 |
| V2 | MVP | Cierre | `flutter analyze` y `flutter test` sin fallos. README con descripción, cómo ejecutar, decisiones y capturas. `flutter build apk` genera un APK que funciona. | V1 |
| **Opcionales** | | | | |
| O1 | Opc. | Búsqueda por nombre o SKU | Filtra la lista mientras se escribe. | P1 |
| O2 | Opc. | CI en GitHub Actions | Ejecuta analyze y test en cada push. | V2 |
| O3 | Opc. | Filtro de historial por tipo | Entradas, salidas o todas. | M2 |

## Decisiones técnicas definitivas

- **Plataformas:** Android (iOS opcional). Sin web ni escritorio.
- **Paquetes:** `flutter_riverpod`, `drift`, `drift_flutter` e `intl` (fechas y moneda). Dev: `drift_dev`, `build_runner`.
- **Descartados:** GoRouter, porque con 3 pestañas y pocas pantallas `Navigator` basta. Mocktail, porque se prueba contra Drift en memoria, que detecta más errores que un mock.
- **Estructura:** feature-first, sin capa de dominio. Se usan las clases generadas por Drift como modelos y repositorios que contienen las reglas.
- **Stock:** `stock` vive en el producto y se actualiza junto con el movimiento en una transacción. Los movimientos son inmutables y las correcciones se hacen con un movimiento nuevo.
- **Cantidades y precios:** enteros, y precio en centavos. Una sola moneda, con símbolo en una constante.
- **Motivo:** obligatorio y de lista fija, sin campo de nota.
- **Errores de negocio:** excepciones tipadas que la UI traduce a mensajes en español.
- **Pruebas:** repositorios con base en memoria, que es el núcleo, y widget tests solo en formularios y bloqueos clave. Nota: `flutter test` necesita SQLite instalado en la máquina (en Windows, la DLL).

## Orden recomendado

S1 → S2 → S3 → D1 → D2 → D3 → L1 → L2 → L5 → L6 → P1 → P2 *(hito 1: alta y lista de productos)* → L3 → L4 → P3 → M1 *(hito 2: movimientos)* → M2 → H1 → V1 → V2

## Definición de terminado del MVP

- Todas las tareas MVP están completas con sus criterios cumplidos.
- Un usuario puede crear, editar y eliminar productos (con las reglas de borrado), registrar entradas y salidas y consultar el historial.
- El stock nunca queda negativo y siempre coincide con la suma de los movimientos.
- El dashboard muestra total, stock bajo y valor del inventario.
- Los datos persisten tras reiniciar y todo funciona sin internet.
- `analyze` y `test` pasan limpios, y el README y el APK están listos.
