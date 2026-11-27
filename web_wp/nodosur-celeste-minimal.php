<?php
/**
 * Plugin Name: NodoSur - Tienda de Ropa Celeste Minimalista & Carrito Funcional
 * Description: Paleta celeste minimalista, mini-carrito deslizable AJAX, selector de tallas, guia de tallas, barra de envio gratis y filtros rapidos para NodoSur.
 * Version: 2.0.0
 */

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

define( 'NODOSUR_FREE_SHIPPING_MIN', 45000 );

/* ==========================================================================
 * 1. ESTILOS CELESTE MINIMALISTA + UI TIENDA DE ROPA
 * ========================================================================== */
add_action( 'wp_head', function () {
    if ( is_admin() ) {
        return;
    }
    ?>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,500;0,600;1,400&family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style id="nodosur-celeste-minimal-css">
        :root {
            --ns-sky-50: #f0f9ff;
            --ns-sky-100: #e0f2fe;
            --ns-sky-200: #bae6fd;
            --ns-sky-300: #7dd3fc;
            --ns-sky-400: #38bdf8;
            --ns-sky-500: #0ea5e9;
            --ns-sky-600: #0284c7;
            --ns-sky-700: #0369a1;
            --ns-ink: #0f172a;
            --ns-muted: #475569;
            --ns-white: #ffffff;

            --ast-global-color-0: #0ea5e9 !important;
            --ast-global-color-1: #0284c7 !important;
            --ast-global-color-2: #0f172a !important;
            --ast-global-color-3: #475569 !important;
            --ast-global-color-4: #f0f9ff !important;
            --ast-global-color-5: #ffffff !important;
            --ast-global-color-6: #e0f2fe !important;
            --ast-global-color-7: #0c4a6e !important;
            --ast-global-color-8: #bae6fd !important;

            --e-global-color-primary: #0ea5e9 !important;
            --e-global-color-secondary: #38bdf8 !important;
            --e-global-color-text: #334155 !important;
            --e-global-color-accent: #0284c7 !important;
        }

        body, body.ast-desktop, .site, .site-content {
            background-color: var(--ns-white) !important;
            color: var(--ns-ink) !important;
            font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif !important;
            -webkit-font-smoothing: antialiased;
        }

        h1, h2, h3, h4,
        .entry-title, .elementor-heading-title, .hfe-infocard-title, .woocommerce-products-header__title {
            font-family: 'Cormorant Garamond', Georgia, serif !important;
            letter-spacing: 0.02em;
            font-weight: 500 !important;
        }

        /* Cintillo superior */
        .nodosur-top-ribbon {
            background: linear-gradient(90deg, #e0f2fe 0%, #f0f9ff 50%, #e0f2fe 100%);
            color: #0369a1;
            text-align: center;
            font-size: 11px;
            font-weight: 600;
            letter-spacing: 0.16em;
            text-transform: uppercase;
            padding: 9px 16px;
            border-bottom: 1px solid #bae6fd;
        }

        /* Header cristal celeste */
        .site-header, .ast-primary-header-bar, .ast-above-header-bar, .ast-below-header-bar, header#masthead {
            background: rgba(255, 255, 255, 0.94) !important;
            backdrop-filter: blur(12px);
            -webkit-backdrop-filter: blur(12px);
            border-bottom: 1px solid var(--ns-sky-100) !important;
            box-shadow: 0 2px 16px rgba(14, 165, 233, 0.05) !important;
        }

        .site-header .site-title a,
        .site-header .main-header-menu .menu-link,
        .ast-builder-menu .menu-item > .menu-link,
        .ast-site-header-cart .ast-cart-menu-wrap,
        .ast-header-search .ast-search-icon {
            color: var(--ns-ink) !important;
            font-family: 'Plus Jakarta Sans', sans-serif !important;
            font-size: 13px !important;
            font-weight: 500 !important;
            letter-spacing: 0.08em !important;
            text-transform: uppercase;
            transition: color 0.2s ease !important;
        }

        .site-header .main-header-menu .menu-link:hover,
        .ast-builder-menu .menu-item.current-menu-item > .menu-link,
        .ast-builder-menu .menu-item > .menu-link:hover {
            color: var(--ns-sky-600) !important;
        }

        .ast-site-header-cart .count,
        .ast-addon-cart-wrap .ast-woo-header-cart-total {
            background-color: var(--ns-sky-500) !important;
            color: #ffffff !important;
            border-color: var(--ns-sky-500) !important;
        }

        .elementor-background-overlay {
            background: linear-gradient(135deg, rgba(12, 74, 110, 0.58) 0%, rgba(14, 165, 233, 0.28) 100%) !important;
        }

        a { color: var(--ns-sky-600); transition: all 0.2s ease; }
        a:hover { color: var(--ns-sky-700); }

        button:not(.ns-size-btn):not(.ns-drawer-close):not(.ns-modal-close):not(.ns-size-guide-trigger):not(.ns-floating-cart-btn),
        .ast-button, .button, input[type="submit"], .elementor-button,
        .woocommerce a.button, .woocommerce button.button, .woocommerce input.button,
        .woocommerce #respond input#submit, .woocommerce a.button.alt, .woocommerce button.button.alt,
        .wp-block-button__link {
            background-color: var(--ns-sky-500) !important;
            color: #ffffff !important;
            border: 1px solid var(--ns-sky-500) !important;
            border-radius: 999px !important;
            font-family: 'Plus Jakarta Sans', sans-serif !important;
            font-size: 12px !important;
            font-weight: 600 !important;
            letter-spacing: 0.11em !important;
            text-transform: uppercase !important;
            padding: 12px 24px !important;
            box-shadow: 0 6px 18px rgba(14, 165, 233, 0.20) !important;
            transition: all 0.25s ease !important;
        }

        button:not(.ns-size-btn):not(.ns-drawer-close):not(.ns-modal-close):not(.ns-size-guide-trigger):not(.ns-floating-cart-btn):hover,
        .ast-button:hover, .button:hover, input[type="submit"]:hover, .elementor-button:hover,
        .woocommerce a.button:hover, .woocommerce button.button:hover, .woocommerce input.button:hover,
        .woocommerce a.button.alt:hover, .woocommerce button.button.alt:hover, .wp-block-button__link:hover {
            background-color: var(--ns-sky-600) !important;
            border-color: var(--ns-sky-600) !important;
            color: #ffffff !important;
            transform: translateY(-1px);
            box-shadow: 0 10px 24px rgba(2, 132, 199, 0.28) !important;
        }

        /* Tarjetas de prendas WooCommerce */
        .woocommerce ul.products li.product, .woocommerce-page ul.products li.product {
            background: var(--ns-white) !important;
            border: 1px solid var(--ns-sky-100) !important;
            border-radius: 16px !important;
            padding: 14px 14px 20px !important;
            transition: transform 0.28s ease, box-shadow 0.28s ease, border-color 0.28s ease !important;
            overflow: hidden;
        }

        .woocommerce ul.products li.product:hover, .woocommerce-page ul.products li.product:hover {
            transform: translateY(-4px);
            border-color: var(--ns-sky-300) !important;
            box-shadow: 0 16px 34px rgba(14, 165, 233, 0.12) !important;
        }

        .woocommerce ul.products li.product a img {
            border-radius: 12px !important;
            transition: transform 0.45s ease !important;
        }
        .woocommerce ul.products li.product:hover a img { transform: scale(1.03); }

        .woocommerce ul.products li.product .woocommerce-loop-product__title {
            font-family: 'Plus Jakarta Sans', sans-serif !important;
            font-size: 15px !important;
            font-weight: 600 !important;
            color: var(--ns-ink) !important;
            margin-top: 10px !important;
        }

        .woocommerce ul.products li.product .price,
        .woocommerce div.product p.price, .woocommerce div.product span.price {
            color: var(--ns-sky-700) !important;
            font-weight: 600 !important;
            font-size: 16px !important;
        }

        .woocommerce span.onsale {
            background-color: var(--ns-sky-100) !important;
            color: var(--ns-sky-700) !important;
            border: 1px solid var(--ns-sky-200) !important;
            border-radius: 999px !important;
            font-size: 10px !important;
            font-weight: 700 !important;
            letter-spacing: 0.1em;
            text-transform: uppercase;
            padding: 4px 10px !important;
            min-height: auto !important;
            line-height: 1.4 !important;
        }

        /* Inputs, Carrito y Checkout */
        input[type="text"], input[type="email"], input[type="tel"], input[type="password"],
        input[type="search"], input[type="number"], textarea, select {
            background-color: var(--ns-sky-50) !important;
            border: 1px solid var(--ns-sky-200) !important;
            border-radius: 10px !important;
            color: var(--ns-ink) !important;
            padding: 10px 14px !important;
        }

        input:focus, textarea:focus, select:focus {
            outline: none !important;
            border-color: var(--ns-sky-500) !important;
            box-shadow: 0 0 0 3px rgba(14, 165, 233, 0.16) !important;
            background-color: #ffffff !important;
        }

        .woocommerce table.shop_table {
            border: 1px solid var(--ns-sky-100) !important;
            border-radius: 14px !important;
            overflow: hidden;
            background: #ffffff;
        }
        .woocommerce table.shop_table th {
            background: var(--ns-sky-50) !important;
            color: var(--ns-sky-700) !important;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.08em;
        }

        /* Barra de progreso Envio Gratis */
        .ns-shipping-bar {
            background: var(--ns-sky-50);
            border: 1px solid var(--ns-sky-200);
            border-radius: 12px;
            padding: 12px 16px;
            margin: 0 0 18px 0;
            font-size: 13px;
            color: var(--ns-sky-700);
        }
        .ns-shipping-track {
            width: 100%;
            height: 7px;
            background: var(--ns-sky-100);
            border-radius: 999px;
            margin-top: 8px;
            overflow: hidden;
        }
        .ns-shipping-fill {
            height: 100%;
            background: linear-gradient(90deg, #38bdf8, #0284c7);
            border-radius: 999px;
            transition: width 0.35s ease;
        }

        /* Selector de tallas minimalista */
        .ns-size-selector-wrap {
            margin: 16px 0 20px 0;
            padding: 14px 16px;
            background: var(--ns-sky-50);
            border: 1px solid var(--ns-sky-100);
            border-radius: 14px;
        }
        .ns-size-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            color: var(--ns-ink);
        }
        .ns-size-guide-trigger {
            background: transparent !important;
            border: none !important;
            color: var(--ns-sky-600) !important;
            font-size: 12px !important;
            font-weight: 600 !important;
            text-decoration: underline;
            cursor: pointer;
            padding: 0 !important;
            box-shadow: none !important;
        }
        .ns-size-grid {
            display: flex;
            gap: 8px;
            flex-wrap: wrap;
        }
        .ns-size-btn {
            min-width: 44px;
            height: 38px;
            border-radius: 10px;
            border: 1px solid var(--ns-sky-200);
            background: #ffffff;
            color: var(--ns-ink);
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        .ns-size-btn:hover { border-color: var(--ns-sky-500); color: var(--ns-sky-600); }
        .ns-size-btn.active {
            background: var(--ns-sky-500);
            border-color: var(--ns-sky-500);
            color: #ffffff;
            box-shadow: 0 4px 12px rgba(14, 165, 233, 0.25);
        }

        /* Beneficios de tienda de ropa */
        .ns-trust-badges {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 10px;
            margin-top: 20px;
            padding-top: 16px;
            border-top: 1px solid var(--ns-sky-100);
        }
        .ns-trust-item {
            background: var(--ns-sky-50);
            border: 1px solid var(--ns-sky-100);
            border-radius: 12px;
            padding: 10px;
            text-align: center;
            font-size: 11px;
            color: var(--ns-muted);
            line-height: 1.4;
        }
        .ns-trust-item strong { display: block; color: var(--ns-sky-700); font-size: 12px; margin-bottom: 2px; }

        /* Buscador y filtros rapidos en Tienda */
        .ns-shop-toolbar {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            align-items: center;
            justify-content: space-between;
            background: var(--ns-sky-50);
            border: 1px solid var(--ns-sky-100);
            border-radius: 14px;
            padding: 12px 16px;
            margin-bottom: 24px;
        }
        .ns-shop-search-form {
            display: flex;
            gap: 8px;
            flex: 1;
            min-width: 240px;
            max-width: 420px;
        }
        .ns-shop-search-form input { flex: 1; background: #ffffff !important; }
        .ns-shop-pills { display: flex; gap: 8px; flex-wrap: wrap; }
        .ns-shop-pill {
            padding: 7px 14px;
            border-radius: 999px;
            background: #ffffff;
            border: 1px solid var(--ns-sky-200);
            color: var(--ns-sky-700) !important;
            font-size: 12px;
            font-weight: 600;
            text-decoration: none !important;
        }
        .ns-shop-pill:hover { background: var(--ns-sky-500); color: #ffffff !important; border-color: var(--ns-sky-500); }

        /* Boton flotante de carrito (izquierda inferior para no chocar con badge de nodo) */
        .ns-floating-cart-btn {
            position: fixed;
            bottom: 20px;
            left: 20px;
            z-index: 99990;
            display: inline-flex;
            align-items: center;
            gap: 10px;
            background: linear-gradient(135deg, #0ea5e9 0%, #0284c7 100%);
            color: #ffffff;
            border: 2px solid #e0f2fe;
            border-radius: 999px;
            padding: 11px 18px;
            font-family: 'Plus Jakarta Sans', sans-serif;
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
            box-shadow: 0 10px 28px rgba(2, 132, 199, 0.35);
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        .ns-floating-cart-btn:hover { transform: translateY(-2px); box-shadow: 0 14px 32px rgba(2, 132, 199, 0.45); }
        .ns-cart-badge {
            background: #ffffff;
            color: #0284c7;
            border-radius: 999px;
            min-width: 22px;
            height: 22px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 12px;
            font-weight: 700;
            padding: 0 6px;
        }

        /* Drawer lateral del Mini-Carrito */
        .ns-drawer-overlay {
            position: fixed;
            inset: 0;
            background: rgba(15, 23, 42, 0.42);
            backdrop-filter: blur(4px);
            z-index: 99995;
            opacity: 0;
            pointer-events: none;
            transition: opacity 0.25s ease;
        }
        .ns-drawer-overlay.open { opacity: 1; pointer-events: auto; }

        .ns-cart-drawer {
            position: fixed;
            top: 0;
            right: -420px;
            width: 390px;
            max-width: 92vw;
            height: 100vh;
            background: #ffffff;
            z-index: 99998;
            box-shadow: -12px 0 40px rgba(15, 23, 42, 0.16);
            display: flex;
            flex-direction: column;
            transition: right 0.3s cubic-bezier(0.22, 1, 0.36, 1);
            border-left: 1px solid var(--ns-sky-100);
        }
        .ns-cart-drawer.open { right: 0; }
        .ns-drawer-head {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 18px 20px;
            background: var(--ns-sky-50);
            border-bottom: 1px solid var(--ns-sky-100);
        }
        .ns-drawer-head h3 { margin: 0; font-size: 22px; color: var(--ns-ink); }
        .ns-drawer-close {
            background: #ffffff;
            border: 1px solid var(--ns-sky-200);
            color: var(--ns-ink);
            width: 32px;
            height: 32px;
            border-radius: 50%;
            font-size: 18px;
            cursor: pointer;
            line-height: 1;
        }
        .ns-drawer-body {
            flex: 1;
            overflow-y: auto;
            padding: 18px 20px;
        }
        .ns-mini-item {
            display: flex;
            gap: 12px;
            align-items: center;
            padding: 12px 0;
            border-bottom: 1px solid var(--ns-sky-100);
        }
        .ns-mini-item img { width: 58px; height: 70px; object-fit: cover; border-radius: 10px; border: 1px solid var(--ns-sky-100); }
        .ns-mini-info { flex: 1; font-size: 13px; }
        .ns-mini-info a { color: var(--ns-ink); font-weight: 600; text-decoration: none; display: block; }
        .ns-mini-meta { color: var(--ns-muted); font-size: 12px; margin-top: 3px; }
        .ns-mini-remove { color: #94a3b8; font-size: 18px; text-decoration: none; padding: 4px 8px; }
        .ns-mini-remove:hover { color: #ef4444; }
        .ns-drawer-foot {
            padding: 16px 20px 22px;
            border-top: 1px solid var(--ns-sky-100);
            background: var(--ns-sky-50);
        }
        .ns-drawer-total {
            display: flex;
            justify-content: space-between;
            font-size: 16px;
            font-weight: 700;
            color: var(--ns-ink);
            margin-bottom: 14px;
        }
        .ns-drawer-actions { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
        .ns-btn-outline {
            display: inline-block;
            text-align: center;
            padding: 11px 14px;
            border-radius: 999px;
            border: 1px solid var(--ns-sky-500);
            color: var(--ns-sky-600) !important;
            background: #ffffff;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            text-decoration: none !important;
        }
        .ns-btn-solid {
            display: inline-block;
            text-align: center;
            padding: 11px 14px;
            border-radius: 999px;
            border: 1px solid var(--ns-sky-500);
            color: #ffffff !important;
            background: var(--ns-sky-500);
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            text-decoration: none !important;
        }

        /* Modal Guia de Tallas */
        .ns-size-modal {
            position: fixed;
            inset: 0;
            background: rgba(15, 23, 42, 0.5);
            backdrop-filter: blur(4px);
            z-index: 99999;
            display: none;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .ns-size-modal.open { display: flex; }
        .ns-size-modal-card {
            background: #ffffff;
            border: 1px solid var(--ns-sky-200);
            border-radius: 18px;
            max-width: 520px;
            width: 100%;
            padding: 24px;
            box-shadow: 0 24px 50px rgba(15, 23, 42, 0.22);
        }
        .ns-size-modal-card table { width: 100%; border-collapse: collapse; margin-top: 12px; font-size: 13px; }
        .ns-size-modal-card th { background: var(--ns-sky-50); color: var(--ns-sky-700); padding: 9px; text-align: center; border-bottom: 1px solid var(--ns-sky-200); }
        .ns-size-modal-card td { padding: 9px; text-align: center; border-bottom: 1px solid #f1f5f9; }

        /* Footer minimalista */
        footer.site-footer, .ast-primary-footer-bar, .ast-below-footer-bar, .ast-above-footer-bar, .site-below-footer-wrap {
            background-color: var(--ns-sky-50) !important;
            color: var(--ns-muted) !important;
            border-top: 1px solid var(--ns-sky-200) !important;
        }
        footer.site-footer a, .site-footer h1, .site-footer h2, .site-footer h3, .site-footer h4 { color: var(--ns-ink) !important; }
        footer.site-footer a:hover { color: var(--ns-sky-600) !important; }
    </style>
    <?php
}, 9999 );

/* Cintillo superior */
add_action( 'wp_body_open', function () {
    if ( is_admin() ) {
        return;
    }
    echo '<div class="nodosur-top-ribbon">NODOSUR ATELIER &nbsp;&middot;&nbsp; ENV&Iacute;O GRATIS SOBRE $45.000 &nbsp;&middot;&nbsp; CAMBIOS SIN COSTO 30 D&Iacute;AS</div>';
}, 1 );

/* ==========================================================================
 * 2. BARRA DE PROGRESO ENVIO GRATIS (Helper)
 * ========================================================================== */
function nodosur_render_shipping_bar() {
    if ( ! function_exists( 'WC' ) || ! WC()->cart ) {
        return '';
    }
    $subtotal = (float) WC()->cart->get_subtotal();
    $min      = NODOSUR_FREE_SHIPPING_MIN;
    $pct      = $min > 0 ? min( 100, round( ( $subtotal / $min ) * 100 ) ) : 100;
    $remaining = max( 0, $min - $subtotal );

    if ( $remaining <= 0 ) {
        $msg = '&#10003; <strong>&iexcl;Felicidades!</strong> Tu pedido califica para <strong>Env&iacute;o Gratis</strong> a todo Chile.';
    } else {
        $msg = 'Te faltan <strong>' . wc_price( $remaining ) . '</strong> para obtener <strong>Env&iacute;o Gratis</strong>.';
    }

    return '<div class="ns-shipping-bar"><div>' . $msg . '</div><div class="ns-shipping-track"><div class="ns-shipping-fill" style="width:' . $pct . '%"></div></div></div>';
}

add_action( 'woocommerce_before_cart', function () {
    echo nodosur_render_shipping_bar();
} );

/* ==========================================================================
 * 3. SELECTOR DE TALLAS PARA PRENDAS SIMPLES + GUIA DE TALLAS + TRUST BADGES
 * ========================================================================== */
add_action( 'woocommerce_before_add_to_cart_button', function () {
    global $product;
    if ( ! $product ) {
        return;
    }
    if ( $product->is_type( 'simple' ) ) {
        ?>
        <div class="ns-size-selector-wrap">
            <div class="ns-size-header">
                <span>Selecciona tu talla: <strong id="ns-selected-size-label">M</strong></span>
                <button type="button" class="ns-size-guide-trigger" onclick="document.getElementById('ns-size-modal').classList.add('open')">Gu&iacute;a de tallas</button>
            </div>
            <div class="ns-size-grid">
                <?php foreach ( array( 'XS', 'S', 'M', 'L', 'XL' ) as $sz ) : ?>
                    <button type="button" class="ns-size-btn <?php echo $sz === 'M' ? 'active' : ''; ?>" data-size="<?php echo esc_attr( $sz ); ?>"><?php echo esc_html( $sz ); ?></button>
                <?php endforeach; ?>
            </div>
            <input type="hidden" name="nodosur_talla" id="nodosur_talla_input" value="M">
        </div>
        <?php
    } else {
        echo '<div style="margin: 8px 0 14px;"><button type="button" class="ns-size-guide-trigger" onclick="document.getElementById(\'ns-size-modal\').classList.add(\'open\')">Ver Gu&iacute;a de Tallas</button></div>';
    }
} );

add_filter( 'woocommerce_add_cart_item_data', function ( $cart_item_data, $product_id ) {
    if ( ! empty( $_POST['nodosur_talla'] ) ) {
        $cart_item_data['nodosur_talla'] = sanitize_text_field( wp_unslash( $_POST['nodosur_talla'] ) );
    }
    return $cart_item_data;
}, 10, 2 );

add_filter( 'woocommerce_get_item_data', function ( $item_data, $cart_item ) {
    if ( ! empty( $cart_item['nodosur_talla'] ) ) {
        $item_data[] = array(
            'key'   => 'Talla',
            'value' => esc_html( $cart_item['nodosur_talla'] ),
        );
    }
    return $item_data;
}, 10, 2 );

add_action( 'woocommerce_checkout_create_order_line_item', function ( $item, $cart_item_key, $values ) {
    if ( ! empty( $values['nodosur_talla'] ) ) {
        $item->add_meta_data( 'Talla', $values['nodosur_talla'], true );
    }
}, 10, 3 );

add_action( 'woocommerce_after_add_to_cart_form', function () {
    ?>
    <div class="ns-trust-badges">
        <div class="ns-trust-item"><strong>Env&iacute;o R&aacute;pido</strong>Despacho a todo Chile 24-72h</div>
        <div class="ns-trust-item"><strong>Cambio Gratis</strong>Hasta 30 d&iacute;as en tallas</div>
        <div class="ns-trust-item"><strong>Compra Segura</strong>Transferencia o contra entrega</div>
    </div>
    <?php
} );

/* ==========================================================================
 * 4. BARRA DE BUSQUEDA Y FILTROS RAPIDOS EN TIENDA (/shop/)
 * ========================================================================== */
add_action( 'woocommerce_before_shop_loop', function () {
    $shop_url = function_exists( 'wc_get_page_permalink' ) ? wc_get_page_permalink( 'shop' ) : home_url( '/shop/' );
    $q        = isset( $_GET['s'] ) ? sanitize_text_field( wp_unslash( $_GET['s'] ) ) : '';
    ?>
    <div class="ns-shop-toolbar">
        <form class="ns-shop-search-form" method="get" action="<?php echo esc_url( $shop_url ); ?>">
            <input type="search" name="s" value="<?php echo esc_attr( $q ); ?>" placeholder="Buscar prendas (ej. Blazer, Dress, Camiseta)...">
            <input type="hidden" name="post_type" value="product">
            <button type="submit">Buscar</button>
        </form>
        <div class="ns-shop-pills">
            <a class="ns-shop-pill" href="<?php echo esc_url( $shop_url ); ?>">Todas</a>
            <a class="ns-shop-pill" href="<?php echo esc_url( add_query_arg( 'orderby', 'price', $shop_url ) ); ?>">Menor precio</a>
            <a class="ns-shop-pill" href="<?php echo esc_url( add_query_arg( 'orderby', 'price-desc', $shop_url ) ); ?>">Mayor precio</a>
            <a class="ns-shop-pill" href="<?php echo esc_url( add_query_arg( 'orderby', 'date', $shop_url ) ); ?>">Novedades</a>
        </div>
    </div>
    <?php
}, 15 );

/* ==========================================================================
 * 5. MINI-CARRITO DESLIZABLE FLOTANTE + MODAL GUIA DE TALLAS
 * ========================================================================== */
function nodosur_render_mini_cart_inner() {
    if ( ! function_exists( 'WC' ) || ! WC()->cart ) {
        return '<p style="color:#64748b;">Tu carrito est&aacute; vac&iacute;o.</p>';
    }
    ob_start();
    echo nodosur_render_shipping_bar();
    $items = WC()->cart->get_cart();
    if ( empty( $items ) ) {
        echo '<div style="text-align:center; padding: 36px 12px; color:#64748b;">';
        echo '<p style="font-size:15px; margin-bottom:14px;">Tu bolsa de compras est&aacute; vac&iacute;a.</p>';
        echo '<a class="ns-btn-solid" href="' . esc_url( wc_get_page_permalink( 'shop' ) ) . '">Explorar prendas</a>';
        echo '</div>';
    } else {
        foreach ( $items as $cart_item_key => $cart_item ) {
            $_product = $cart_item['data'];
            if ( ! $_product || ! $_product->exists() || $cart_item['quantity'] <= 0 ) {
                continue;
            }
            $name  = $_product->get_name();
            $thumb = $_product->get_image( 'thumbnail' );
            $price = WC()->cart->get_product_price( $_product );
            $url   = $_product->is_visible() ? $_product->get_permalink( $cart_item ) : '';
            $talla = ! empty( $cart_item['nodosur_talla'] ) ? ' &middot; Talla: ' . esc_html( $cart_item['nodosur_talla'] ) : '';
            $rem   = wc_get_cart_remove_url( $cart_item_key );
            echo '<div class="ns-mini-item">';
            echo $thumb;
            echo '<div class="ns-mini-info">';
            echo $url ? '<a href="' . esc_url( $url ) . '">' . esc_html( $name ) . '</a>' : '<strong>' . esc_html( $name ) . '</strong>';
            echo '<div class="ns-mini-meta">' . intval( $cart_item['quantity'] ) . ' &times; ' . $price . $talla . '</div>';
            echo '</div>';
            echo '<a class="ns-mini-remove" href="' . esc_url( $rem ) . '" title="Quitar">&times;</a>';
            echo '</div>';
        }
    }
    return ob_get_clean();
}

add_filter( 'woocommerce_add_to_cart_fragments', function ( $fragments ) {
    if ( ! function_exists( 'WC' ) || ! WC()->cart ) {
        return $fragments;
    }
    $count = WC()->cart->get_cart_contents_count();
    $sub   = WC()->cart->get_cart_subtotal();
    $fragments['#ns-cart-count']       = '<span id="ns-cart-count" class="ns-cart-badge">' . intval( $count ) . '</span>';
    $fragments['#ns-cart-subtotal-btn'] = '<span id="ns-cart-subtotal-btn">' . $sub . '</span>';
    $fragments['#ns-drawer-body']      = '<div id="ns-drawer-body" class="ns-drawer-body">' . nodosur_render_mini_cart_inner() . '</div>';
    $fragments['#ns-drawer-subtotal']  = '<span id="ns-drawer-subtotal">' . $sub . '</span>';
    return $fragments;
} );

add_action( 'wp_footer', function () {
    if ( is_admin() || ! function_exists( 'WC' ) || ! WC()->cart ) {
        return;
    }
    $count = WC()->cart->get_cart_contents_count();
    $sub   = WC()->cart->get_cart_subtotal();
    ?>
    <button type="button" class="ns-floating-cart-btn" id="ns-open-cart-btn" aria-label="Abrir carrito">
        <span>&#128717; Mi Bolsa</span>
        <span id="ns-cart-count" class="ns-cart-badge"><?php echo intval( $count ); ?></span>
        <span id="ns-cart-subtotal-btn"><?php echo $sub; ?></span>
    </button>

    <div class="ns-drawer-overlay" id="ns-drawer-overlay"></div>
    <aside class="ns-cart-drawer" id="ns-cart-drawer" aria-label="Carrito de compras">
        <div class="ns-drawer-head">
            <h3>Tu Bolsa de Compras</h3>
            <button type="button" class="ns-drawer-close" id="ns-close-cart-btn">&times;</button>
        </div>
        <div id="ns-drawer-body" class="ns-drawer-body">
            <?php echo nodosur_render_mini_cart_inner(); ?>
        </div>
        <div class="ns-drawer-foot">
            <div class="ns-drawer-total">
                <span>Subtotal</span>
                <span id="ns-drawer-subtotal"><?php echo $sub; ?></span>
            </div>
            <div class="ns-drawer-actions">
                <a class="ns-btn-outline" href="<?php echo esc_url( wc_get_cart_url() ); ?>">Ver Carrito</a>
                <a class="ns-btn-solid" href="<?php echo esc_url( wc_get_checkout_url() ); ?>">Finalizar Compra</a>
            </div>
        </div>
    </aside>

    <div class="ns-size-modal" id="ns-size-modal">
        <div class="ns-size-modal-card">
            <div style="display:flex; justify-content:space-between; align-items:center;">
                <h3 style="margin:0; font-size:24px;">Gu&iacute;a de Tallas &mdash; NodoSur</h3>
                <button type="button" class="ns-modal-close ns-drawer-close" onclick="document.getElementById('ns-size-modal').classList.remove('open')">&times;</button>
            </div>
            <p style="font-size:13px; color:#475569; margin:6px 0 0;">Medidas de referencia en cent&iacute;metros (calce regular minimalista):</p>
            <table>
                <thead><tr><th>Talla</th><th>Pecho (cm)</th><th>Cintura (cm)</th><th>Cadera (cm)</th></tr></thead>
                <tbody>
                    <tr><td><strong>XS</strong></td><td>82 - 86</td><td>64 - 68</td><td>88 - 92</td></tr>
                    <tr><td><strong>S</strong></td><td>87 - 92</td><td>69 - 74</td><td>93 - 98</td></tr>
                    <tr><td><strong>M</strong></td><td>93 - 98</td><td>75 - 80</td><td>99 - 104</td></tr>
                    <tr><td><strong>L</strong></td><td>99 - 105</td><td>81 - 87</td><td>105 - 111</td></tr>
                    <tr><td><strong>XL</strong></td><td>106 - 113</td><td>88 - 95</td><td>112 - 119</td></tr>
                </tbody>
            </table>
        </div>
    </div>

    <script>
    (function() {
        var openBtn = document.getElementById('ns-open-cart-btn');
        var closeBtn = document.getElementById('ns-close-cart-btn');
        var drawer = document.getElementById('ns-cart-drawer');
        var overlay = document.getElementById('ns-drawer-overlay');
        function openDrawer() { drawer.classList.add('open'); overlay.classList.add('open'); }
        function closeDrawer() { drawer.classList.remove('open'); overlay.classList.remove('open'); }
        if (openBtn) openBtn.addEventListener('click', openDrawer);
        if (closeBtn) closeBtn.addEventListener('click', closeDrawer);
        if (overlay) overlay.addEventListener('click', closeDrawer);

        document.querySelectorAll('.ns-size-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                document.querySelectorAll('.ns-size-btn').forEach(function(b) { b.classList.remove('active'); });
                btn.classList.add('active');
                var sz = btn.getAttribute('data-size');
                var inp = document.getElementById('nodosur_talla_input');
                var lbl = document.getElementById('ns-selected-size-label');
                if (inp) inp.value = sz;
                if (lbl) lbl.textContent = sz;
            });
        });

        var modal = document.getElementById('ns-size-modal');
        if (modal) modal.addEventListener('click', function(e) { if (e.target === modal) modal.classList.remove('open'); });

        if (window.jQuery) {
            jQuery(document.body).on('added_to_cart', function() { openDrawer(); });
        }
    })();
    </script>
    <?php
}, 99 );
