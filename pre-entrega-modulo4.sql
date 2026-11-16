BEGIN;

CREATE TABLE clientes(
	id SERIAL PRIMARY KEY, --id autoincremental
	nombre VARCHAR(20) NOT NULL, --el nombre no puede ser nulo
	apellido VARCHAR(20) NOT NULL, --lo mismo el apellido
	email VARCHAR(50) UNIQUE NOT NULL, --el email no se puede repetir
	fecha_nacimiento DATE NOT NULL 
);

CREATE TABLE categorias(
	id SERIAL PRIMARY KEY, --id autoincremental
	nombre VARCHAR(50) UNIQUE NOT NULL --el nombre no puede ser nulo
);

CREATE TABLE productos(
	id SERIAL PRIMARY KEY, --id autoincremental
	nombre VARCHAR(50) NOT NULL, --el nombre no puede ser nulo
	stock INT NOT NULL,
	id_categoria INT NOT NULL,
	precio NUMERIC(10, 2) NOT NULL,
	CONSTRAINT chk_stock_real CHECK(stock >= 0), --no puede haber stock negativo
	CONSTRAINT chk_precio_positivo CHECK(precio >= 0), --no pueden ser precios negativos
	CONSTRAINT fk_id_categorias FOREIGN KEY (id_categoria) REFERENCES categorias(id) --FK que toma el id de categoría
);

CREATE TABLE ventas(
	id SERIAL PRIMARY KEY, --id autoincremental
	id_producto INT NOT NULL, 
	id_cliente INT NOT NULL,
	cantidad INT NOT NULL,
	precio_unitario NUMERIC(20, 2) NOT NULL,
	fecha DATE NOT NULL DEFAULT CURRENT_DATE,
	CONSTRAINT chk_cantidad_positiva CHECK(cantidad > 0), --no puede haber una venta de 0 productos
	CONSTRAINT chk_monto_positivo CHECK(precio_unitario >= 0), --no se puede hacer una venta nula
	CONSTRAINT fk_id_productos FOREIGN KEY (id_producto) REFERENCES productos(id), --FK que toma el id de producto
	CONSTRAINT fk_id_clientes FOREIGN KEY (id_cliente) REFERENCES clientes(id) --FK que toma el id del cliente
);

COMMIT;

-- Consulta 1

SELECT 
    c.nombre AS categoria,
    SUM(v.cantidad) AS unidades_vendidas,
    ROUND(SUM(v.cantidad * v.precio_unitario)::NUMERIC, 2) AS ingreso_total
FROM ventas v
INNER JOIN productos p ON v.id_producto = p.id
INNER JOIN categorias c ON p.id_categoria = c.id
GROUP BY c.nombre
HAVING SUM(v.cantidad * v.precio_unitario) > 500000
ORDER BY ingreso_total DESC;

-- Permite a la gerencia comercial identificar cuáles son las líneas de productos
-- más rentables del negocio en términos de volumen despachado y facturación real,
-- con el fin de optimizar el almacenamiento para esas categorías.
-- Umbral definido en $500,000 porque representa el punto de equilibrio operativo
-- mínimo esperado para considerar una categoría como estratégicamente rentable.

-- Consulta 2

SELECT 
    cl.id,
    cl.nombre AS cliente,
    COALESCE(cl.email, 'Sin email registrado') AS contacto,
    COALESCE(COUNT(v.id), 0) AS total_compras,
    COALESCE(SUM(v.cantidad * v.precio_unitario), 0.00) AS monto_invertido
FROM clientes cl
LEFT JOIN ventas v ON cl.id = v.id_cliente
WHERE v.id IS NULL
GROUP BY cl.id, cl.nombre, cl.email
ORDER BY cl.nombre ASC;

-- Detecta usuarios registrados en la base de datos que aún no realizaron su
-- primera transacción, con el fin de buscar incentivos para que hagan su 
-- primera compra (ya sea cupones de bienvenida u otro).


-- Consulta 3

SELECT 
    cl.nombre AS cliente,
    (
        SELECT p_sub.nombre
        FROM ventas v_sub
        INNER JOIN productos p_sub ON v_sub.id_producto = p_sub.id
        WHERE v_sub.id_cliente = cl.id
        GROUP BY p_sub.id, p_sub.nombre
        ORDER BY COUNT(*) DESC
        LIMIT 1
    ) AS producto_mas_comprado,
    MAX(v.fecha) AS ultima_transaccion
FROM clientes cl
INNER JOIN ventas v ON cl.id = v.id_cliente
INNER JOIN productos p ON v.id_producto = p.id
GROUP BY cl.id, cl.nombre
ORDER BY ultima_transaccion DESC; 

-- Permite conocer cuál es el artículo favorito (el más comprado en frecuencia)
-- de cada comprador activo y qué tan reciente fue su última operación, con el
-- fin de saber que tan seguido se debe reponer stock para dicho cliente.
