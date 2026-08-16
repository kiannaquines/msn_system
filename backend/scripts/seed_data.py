#!/usr/bin/env python3
import os
import sys
import uuid
from datetime import datetime, timedelta, timezone
from sqlalchemy import select, delete

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal, engine, Base
from app.models import (
    Address,
    AuditLog,
    DeliveryEvent,
    Feedback,
    LocationPoint,
    MenuItem,
    Order,
    OrderItem,
    Store,
    User,
)
from app.security import hash_password


def now_offset(minutes: int = 0) -> datetime:
    return datetime.now(timezone.utc) + timedelta(minutes=minutes)


def seed() -> None:
    print("📍 Seeding authentic Toril, Davao City stores, menus, riders, and delivery data...")
    db = SessionLocal()
    try:
        # Clear existing transactional order data for a fresh state
        db.query(Feedback).delete()
        db.query(LocationPoint).delete()
        db.query(DeliveryEvent).delete()
        db.query(OrderItem).delete()
        db.query(Order).delete()
        db.query(AuditLog).delete()
        db.commit()

        # =========================================================
        # 1. USERS & ACCOUNTS
        # =========================================================
        # Admin Accounts
        admin = db.scalar(select(User).where(User.email == "admin@mns.ph"))
        if not admin:
            admin = User(
                email="admin@mns.ph",
                password_hash=hash_password("AdminPass123!"),
                full_name="M&S System Administrator",
                phone="+639178889999",
                role="admin",
                is_active=True,
            )
            db.add(admin)
        else:
            admin.full_name = "M&S System Administrator"
            admin.password_hash = hash_password("AdminPass123!")

        admin2 = db.scalar(select(User).where(User.email == "admin@mns.com"))
        if not admin2:
            admin2 = User(
                email="admin@mns.com",
                password_hash=hash_password("Password123!"),
                full_name="Operations Manager Toril",
                phone="+639178880001",
                role="admin",
                is_active=True,
            )
            db.add(admin2)
        else:
            admin2.full_name = "Operations Manager Toril"
            admin2.password_hash = hash_password("Password123!")

        # Riders in Davao Toril
        rider1 = db.scalar(select(User).where(User.email == "rider@mns.com"))
        if not rider1:
            rider1 = User(
                email="rider@mns.com",
                password_hash=hash_password("Password123!"),
                full_name="Arnel 'Jun' Dimaculangan",
                phone="+639175551234",
                role="rider",
                rider_status="available",
                is_active=True,
            )
            db.add(rider1)
        else:
            rider1.full_name = "Arnel 'Jun' Dimaculangan"
            rider1.password_hash = hash_password("Password123!")
            rider1.rider_status = "available"

        rider2 = db.scalar(select(User).where(User.email == "rider.ben@mns.com"))
        if not rider2:
            rider2 = User(
                email="rider.ben@mns.com",
                password_hash=hash_password("Password123!"),
                full_name="Benjamin 'Ben' Alcantara",
                phone="+639185552345",
                role="rider",
                rider_status="busy",
                is_active=True,
            )
            db.add(rider2)
        else:
            rider2.rider_status = "busy"

        rider3 = db.scalar(select(User).where(User.email == "rider.carlo@mns.com"))
        if not rider3:
            rider3 = User(
                email="rider.carlo@mns.com",
                password_hash=hash_password("Password123!"),
                full_name="Carlo 'Caloy' Mendoza",
                phone="+639195553456",
                role="rider",
                rider_status="busy",
                is_active=True,
            )
            db.add(rider3)
        else:
            rider3.rider_status = "busy"

        # Customer Accounts
        cust1 = db.scalar(select(User).where(User.email == "customer@mns.ph"))
        if not cust1:
            cust1 = User(
                email="customer@mns.ph",
                password_hash=hash_password("Password123!"),
                full_name="Maria Clara Santos",
                phone="+639171112233",
                role="customer",
                is_active=True,
            )
            db.add(cust1)
        else:
            cust1.full_name = "Maria Clara Santos"
            cust1.password_hash = hash_password("Password123!")

        cust1_alt = db.scalar(select(User).where(User.email == "maria.santos@mns.ph"))
        if not cust1_alt:
            cust1_alt = User(
                email="maria.santos@mns.ph",
                password_hash=hash_password("Password123!"),
                full_name="Maria Santos",
                phone="+639171112234",
                role="customer",
                is_active=True,
            )
            db.add(cust1_alt)
        else:
            cust1_alt.password_hash = hash_password("Password123!")

        cust2 = db.scalar(select(User).where(User.email == "customer@mns.com"))
        if not cust2:
            cust2 = User(
                email="customer@mns.com",
                password_hash=hash_password("Password123!"),
                full_name="Juan dela Cruz",
                phone="+639182224567",
                role="customer",
                is_active=True,
            )
            db.add(cust2)

        cust3 = db.scalar(select(User).where(User.email == "customer.bea@mns.com"))
        if not cust3:
            cust3 = User(
                email="customer.bea@mns.com",
                password_hash=hash_password("Password123!"),
                full_name="Beatriz 'Bea' Alonzo",
                phone="+639193336789",
                role="customer",
                is_active=True,
            )
            db.add(cust3)

        db.flush()
        print("  ✓ Users active (Admin, 3 Toril Riders, Customers)")

        # =========================================================
        # 2. TORIL, DAVAO CITY SAVED CUSTOMER ADDRESSES
        # =========================================================
        db.query(Address).delete()
        addr_maria_home = Address(
            customer_id=cust1.id,
            label="Home (Crossing Bayabas)",
            line1="Purok 4, McArthur Highway, Crossing Bayabas, Toril, Davao City",
            latitude=7.0245,
            longitude=125.5035,
        )
        addr_maria_work = Address(
            customer_id=cust1.id,
            label="Villa Josefina",
            line1="Block 15 Lot 8, Villa Josefina Resort Village, Toril, Davao City",
            latitude=7.0160,
            longitude=125.5060,
        )
        addr_juan_home = Address(
            customer_id=cust2.id,
            label="Bahay (Toril Poblacion)",
            line1="Door 2, Saavedra St., Brgy. Toril Poblacion, Davao City",
            latitude=7.0190,
            longitude=125.4960,
        )
        addr_bea_condo = Address(
            customer_id=cust3.id,
            label="St. Jude Subdivision",
            line1="Phase 2, St. Jude Executive Subdivision, Toril, Davao City",
            latitude=7.0270,
            longitude=125.4940,
        )
        db.add_all([addr_maria_home, addr_maria_work, addr_juan_home, addr_bea_condo])
        db.flush()
        print("  ✓ Toril, Davao City customer delivery addresses created")

        # =========================================================
        # 3. TORIL, DAVAO CITY STORES & PRODUCTS
        # =========================================================
        db.query(MenuItem).delete()
        db.query(Store).delete()

        # Store 1: Penong's Barbecue Seafood & Grill - Toril Branch
        store1 = Store(
            name="Penong's Barbecue Seafood & Grill - Toril",
            description="McArthur Highway, Crossing Bayabas, Toril, Davao City. Famous for juicy Chicken Inato with unlimited rice, savory pork skewers, and sizzling seafood.",
            latitude=7.0235,
            longitude=125.5015,
            is_active=True,
        )
        db.add(store1)
        db.flush()

        s1_items = [
            MenuItem(store_id=store1.id, name="Chicken Inato Paa w/ Rice", description="Quarter leg marinated in annatto calamansi blend, grilled to perfection.", category="Inato Meals", price=175.00, image_path="https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=400&q=80", is_available=True),
            MenuItem(store_id=store1.id, name="Chicken Inato Pecho w/ Rice", description="Juicy breast and wing cut grilled with signature sweet basting sauce.", category="Inato Meals", price=185.00, image_path="https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=400&q=80", is_available=True),
            MenuItem(store_id=store1.id, name="Pork BBQ Skewers (3 Sticks)", description="Tender pork skewers with savory sweet glaze.", category="Grilled BBQ", price=145.00, image_path="https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=400&q=80", is_available=True),
            MenuItem(store_id=store1.id, name="Crispy Pata Special (Family)", description="Deep fried pork knuckle with crunchy skin and tender meat.", category="Popular", price=480.00, image_path="https://images.unsplash.com/photo-1544025162-d76694265947?w=400&q=80", is_available=True),
            MenuItem(store_id=store1.id, name="Sizzling Bangus Sisig", description="Flaked milkfish seasoned with onions, chili, and calamansi on a hot sizzler.", category="Seafood", price=230.00, image_path="https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=400&q=80", is_available=True),
            MenuItem(store_id=store1.id, name="Fresh Kinilaw na Tuna", description="Fresh Davao yellowfin tuna ceviche in vinegar, ginger, and chili.", category="Seafood", price=220.00, image_path="https://images.unsplash.com/photo-1558030006-450675393462?w=400&q=80", is_available=True),
            MenuItem(store_id=store1.id, name="House Calamansi Iced Cooler (1L)", description="Freshly squeezed calamansi cooler with pure honey.", category="Beverages", price=75.00, image_path="https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=400&q=80", is_available=True),
        ]
        db.add_all(s1_items)

        # Store 2: Jollibee Toril Crossing Drive-Thru
        store2 = Store(
            name="Jollibee Toril Crossing Drive-Thru",
            description="McArthur Highway corner Saavedra Street, Toril, Davao City. Home of the world-famous crispy Chickenjoy, Jolly Spaghetti, and Yumburgers.",
            latitude=7.0205,
            longitude=125.4972,
            is_active=True,
        )
        db.add(store2)
        db.flush()

        s2_items = [
            MenuItem(store_id=store2.id, name="1-pc Chickenjoy w/ Rice & Gravy", description="Signature crispylicious, juicylicious fried chicken with hot rice and gravy.", category="Chickenjoy", price=95.00, image_path="https://images.unsplash.com/photo-1569058242253-92a9c755a0ec?w=400&q=80", is_available=True),
            MenuItem(store_id=store2.id, name="2-pc Chickenjoy Meal w/ Drink", description="Two pieces crispy fried chicken with steamed rice and regular iced drink.", category="Chickenjoy", price=189.00, image_path="https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=400&q=80", is_available=True),
            MenuItem(store_id=store2.id, name="Jolly Spaghetti w/ Yumburger Combo", description="Sweet-style spaghetti topped with grated cheddar cheese and beef burger.", category="Combos", price=135.00, image_path="https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=400&q=80", is_available=True),
            MenuItem(store_id=store2.id, name="Cheesy Classic Yumburger", description="100% pure beef patty with signature Thousand Island dressing and cheese.", category="Burgers", price=65.00, image_path="https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80", is_available=True),
            MenuItem(store_id=store2.id, name="Peach Mango Pie (3-Pack Box)", description="Sweet Philippine mango and peach slices in a golden crispy flaky crust.", category="Desserts", price=145.00, image_path="https://images.unsplash.com/photo-1519915028121-7d3463d20b13?w=400&q=80", is_available=True),
            MenuItem(store_id=store2.id, name="Jolly Crispy Fries (Large)", description="Golden potato fries with rich potato flavor.", category="Snacks", price=85.00, image_path="https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400&q=80", is_available=True),
        ]
        db.add_all(s2_items)

        # Store 3: Mang Inasal Gaisano Grand Mall Toril
        store3 = Store(
            name="Mang Inasal - Gaisano Grand Toril",
            description="Ground Floor, Gaisano Grand Mall Toril, McArthur Highway, Toril, Davao City. The Philippines' Nu. 1 Nuot-sa-Inihaw Chicken Inasal and Extra Creamy Halo-Halo.",
            latitude=7.0212,
            longitude=125.4988,
            is_active=True,
        )
        db.add(store3)
        db.flush()

        s3_items = [
            MenuItem(store_id=store3.id, name="PM1 Chicken Inasal Paa (Leg & Thigh)", description="Grilled quarter chicken leg served with chicken oil and steamed rice.", category="Inasal Meals", price=165.00, image_path="https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=400&q=80", is_available=True),
            MenuItem(store_id=store3.id, name="PM2 Chicken Inasal Pecho (Breast & Wing)", description="Savory inasal breast and wing cut with savory spices.", category="Inasal Meals", price=175.00, image_path="https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=400&q=80", is_available=True),
            MenuItem(store_id=store3.id, name="Pork BBQ with Peanut Sauce (2 Sticks)", description="Charcoal grilled skewered pork belly cuts with sweet peanut sauce.", category="Grilled Meals", price=155.00, image_path="https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=400&q=80", is_available=True),
            MenuItem(store_id=store3.id, name="Sizzling Pork Sisig Meal", description="Crispy pork mask with egg, onion, and native chili on a sizzling plate.", category="Sizzling", price=169.00, image_path="https://images.unsplash.com/photo-1544025162-d76694265947?w=400&q=80", is_available=True),
            MenuItem(store_id=store3.id, name="Extra Creamy Halo-Halo Supreme", description="Shaved ice with ube halaya, leche flan, sweetened banana, and ice cream.", category="Desserts", price=99.00, image_path="https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=400&q=80", is_available=True),
            MenuItem(store_id=store3.id, name="Palabok Fiesta Special", description="Rice noodles topped with rich shrimp sauce, crushed chicharon, and egg.", category="Noodles", price=115.00, image_path="https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400&q=80", is_available=True),
        ]
        db.add_all(s3_items)

        # Store 4: Kusina Dabaw - Toril Poblacion
        store4 = Store(
            name="Kusina Dabaw - Toril Poblacion",
            description="Agton Street (near Toril Public Market), Toril Poblacion, Davao City. Traditional Dabawenyo comfort food, Pancit Canton Dabaw, Lechon Kawali, and Seafood.",
            latitude=7.0195,
            longitude=125.4995,
            is_active=True,
        )
        db.add(store4)
        db.flush()

        s4_items = [
            MenuItem(store_id=store4.id, name="Original Pancit Canton Dabaw Bilao", description="Stir-fried egg noodles with pork slices, shrimp, squid balls, and fresh vegetables.", category="Noodles & Bilao", price=195.00, image_path="https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400&q=80", is_available=True),
            MenuItem(store_id=store4.id, name="Crispy Lechon Kawali Platter", description="Golden deep-fried pork belly cubes served with homemade liver sauce.", category="Pork Specials", price=220.00, image_path="https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=400&q=80", is_available=True),
            MenuItem(store_id=store4.id, name="Beef Steak Tagalog (Bistek)", description="Tender beef slices marinated in calamansi and soy sauce topped with onion rings.", category="Beef Specials", price=210.00, image_path="https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&q=80", is_available=True),
            MenuItem(store_id=store4.id, name="Sweet & Spicy Gambas Al Ajillo", description="Plump shrimps sautéed in garlic chili butter oil with bell peppers.", category="Seafood", price=240.00, image_path="https://images.unsplash.com/photo-1559737558-2453e1a0b168?w=400&q=80", is_available=True),
            MenuItem(store_id=store4.id, name="Fresh Mixed Vegetable Chopsuey", description="Cauliflower, broccoli, young corn, and pork in savory thick gravy.", category="Vegetables", price=160.00, image_path="https://images.unsplash.com/photo-1512058564366-18510be2db19?w=400&q=80", is_available=True),
            MenuItem(store_id=store4.id, name="Fresh Buko Pandan Cooler (16oz)", description="Chilled young coconut shreds with fragrant pandan jelly cubes and sweet cream.", category="Beverages", price=65.00, image_path="https://images.unsplash.com/photo-1543362906-acfc16c67564?w=400&q=80", is_available=True),
        ]
        db.add_all(s4_items)

        # Store 5: Balamban Liempo & Lechon Manok Toril
        store5 = Store(
            name="Balamban Liempo & Lechon - Toril",
            description="Saavedra Street, Crossing Bayabas, Toril, Davao City. Celebrated Cebu-style herbed stuffed pork liempo and roasted lechon manok.",
            latitude=7.0188,
            longitude=125.4965,
            is_active=True,
        )
        db.add(store5)
        db.flush()

        s5_items = [
            MenuItem(store_id=store5.id, name="Original Balamban Liempo Whole Slab", description="Herbed pork belly stuffed with lemongrass and secret Cebu spices, roasted crispy.", category="Liempo & Lechon", price=290.00, image_path="https://images.unsplash.com/photo-1544025162-d76694265947?w=400&q=80", is_available=True),
            MenuItem(store_id=store5.id, name="Herbed Roast Lechon Manok (Whole)", description="Juicy charcoal roasted whole chicken filled with garlic and lemongrass.", category="Liempo & Lechon", price=310.00, image_path="https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=400&q=80", is_available=True),
            MenuItem(store_id=store5.id, name="Spicy Roast Lechon Manok (Half)", description="Spiced half chicken roast with chili lemongrass marinade.", category="Liempo & Lechon", price=170.00, image_path="https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=400&q=80", is_available=True),
            MenuItem(store_id=store5.id, name="Grilled Chorizo de Cebu (3pcs)", description="Sweet and garlicky Cebuano pork sausages grilled over coals.", category="Add-ons", price=120.00, image_path="https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=400&q=80", is_available=True),
            MenuItem(store_id=store5.id, name="Crispy Fried Chicken Isaw", description="Crunchy golden fried chicken intestines served with spicy spiced vinegar.", category="Snacks", price=85.00, image_path="https://images.unsplash.com/photo-1562967914-608f82629710?w=400&q=80", is_available=True),
            MenuItem(store_id=store5.id, name="Steamed Fragrant Rice (Cup)", description="Pandan steamed white rice.", category="Add-ons", price=20.00, image_path="https://images.unsplash.com/photo-1512058564366-18510be2db19?w=400&q=80", is_available=True),
        ]
        db.add_all(s5_items)

        # Store 6: Chowking Toril McArthur
        store6 = Store(
            name="Chowking Toril McArthur",
            description="McArthur Highway, Crossing Toril, Davao City. Chinese-Filipino fast food classics: Pork Chao Fan, Siomai, Beef Wonton Mami, and Halo-Halo.",
            latitude=7.0208,
            longitude=125.4978,
            is_active=True,
        )
        db.add(store6)
        db.flush()

        s6_items = [
            MenuItem(store_id=store6.id, name="Pork Chao Fan w/ 4-pc Fried Siomai", description="Wok-fried rice with pork bits topped with crispy steamed-fried pork siomai.", category="Chao Fan Meals", price=139.00, image_path="https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&q=80", is_available=True),
            MenuItem(store_id=store6.id, name="Sweet & Sour Pork Lauriat Meal", description="Crispy pork in sweet red sauce served with chao fan, siomai, pancit, and buchi.", category="Lauriat Meals", price=215.00, image_path="https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400&q=80", is_available=True),
            MenuItem(store_id=store6.id, name="Beef Wonton Mami Noodle Soup", description="Hot steaming broth with tender beef brisket, wonton dumplings, and egg noodles.", category="Mami & Soups", price=145.00, image_path="https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400&q=80", is_available=True),
            MenuItem(store_id=store6.id, name="Steamed Pork Siomai Dimsum (4-pcs)", description="Plump pork and shrimp dimsum with chili garlic oil and soy calamansi dip.", category="Dimsum", price=85.00, image_path="https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80", is_available=True),
            MenuItem(store_id=store6.id, name="Super Sangkap Halo-Halo Supreme", description="Classic 13-ingredient halo-halo topped with rich leche flan and ube ice cream.", category="Desserts", price=105.00, image_path="https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=400&q=80", is_available=True),
            MenuItem(store_id=store6.id, name="Crispy Chicharon Bulaklak", description="Deep fried pork mesentery cracklings with native vinegar dip.", category="Snacks", price=110.00, image_path="https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=400&q=80", is_available=True),
        ]
        db.add_all(s6_items)

        # Store 7: Kapewe Cafe & Dessert Bistro Toril
        store7 = Store(
            name="Kapewe Cafe & Bistro Toril",
            description="Daliao Road, Toril, Davao City. Premium specialty coffee, Spanish lattes, matcha espresso, artisan cheesecake, and savory bites.",
            latitude=7.0175,
            longitude=125.5030,
            is_active=True,
        )
        db.add(store7)
        db.flush()

        s7_items = [
            MenuItem(store_id=store7.id, name="Iced Spanish Caramel Latte (16oz)", description="Double shot espresso with condensed milk and caramel drizzle over ice.", category="Specialty Coffee", price=115.00, image_path="https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=400&q=80", is_available=True),
            MenuItem(store_id=store7.id, name="Toril Dirty Matcha Espresso (16oz)", description="Layered Japanese ceremonial grade matcha with bold espresso shot and milk.", category="Specialty Coffee", price=130.00, image_path="https://images.unsplash.com/photo-1536256263959-770b48d82b0a?w=400&q=80", is_available=True),
            MenuItem(store_id=store7.id, name="Dark Chocolate Brown Sugar Boba", description="Rich dark chocolate with brown sugar tapioca pearls and fresh milk.", category="Milk Tea & Coolers", price=95.00, image_path="https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=400&q=80", is_available=True),
            MenuItem(store_id=store7.id, name="New York Blueberry Cheesecake Slice", description="Velvety baked cream cheese with graham crust and whole blueberry topping.", category="Cakes & Pastries", price=135.00, image_path="https://images.unsplash.com/photo-1533134242443-d4fd215305ad?w=400&q=80", is_available=True),
            MenuItem(store_id=store7.id, name="Crispy Truffle Cheese Fries", description="Golden shoestring potato fries tossed in aromatic white truffle oil and parmesan.", category="Bistro Bites", price=125.00, image_path="https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400&q=80", is_available=True),
            MenuItem(store_id=store7.id, name="Belgian Choco Lava Cake w/ Ice Cream", description="Warm chocolate cake with molten chocolate core served with vanilla scoop.", category="Cakes & Pastries", price=145.00, image_path="https://images.unsplash.com/photo-1533134242443-d4fd215305ad?w=400&q=80", is_available=True),
        ]
        db.add_all(s7_items)
        db.flush()
        print("  ✓ 7 Toril, Davao City Stores & 43 authentic menu items created")

        # =========================================================
        # 4. TORIL ORDERS WITH REALISTIC STATUSES & GPS TRACKS
        # =========================================================
        # ORDER 1: Status = "pending" (Newly ordered by Maria from Penong's Toril)
        o1 = Order(
            customer_id=cust1.id,
            store_id=store1.id,
            address_id=addr_maria_home.id,
            status="pending",
            subtotal=505.00,
            delivery_fee=45.00,
            total=550.00,
            route_distance_km=1.2,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=None,
            created_at=now_offset(-10),
        )
        db.add(o1)
        db.flush()
        db.add_all([
            OrderItem(order_id=o1.id, menu_item_id=s1_items[0].id, name_snapshot=s1_items[0].name, unit_price=s1_items[0].price, quantity=2), # Chicken Inato Paa
            OrderItem(order_id=o1.id, menu_item_id=s1_items[2].id, name_snapshot=s1_items[2].name, unit_price=s1_items[2].price, quantity=1), # Pork BBQ
            OrderItem(order_id=o1.id, menu_item_id=s1_items[6].id, name_snapshot=s1_items[6].name, unit_price=s1_items[6].price, quantity=1), # Calamansi Cooler
        ])

        # ORDER 2: Status = "confirmed" (Jollibee Toril Crossing accepted, waiting for rider assignment)
        o2 = Order(
            customer_id=cust2.id,
            store_id=store2.id,
            address_id=addr_juan_home.id,
            status="confirmed",
            subtotal=389.00,
            delivery_fee=40.00,
            total=429.00,
            route_distance_km=0.9,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=None,
            created_at=now_offset(-22),
        )
        db.add(o2)
        db.flush()
        db.add_all([
            OrderItem(order_id=o2.id, menu_item_id=s2_items[1].id, name_snapshot=s2_items[1].name, unit_price=s2_items[1].price, quantity=1), # 2-pc Chickenjoy
            OrderItem(order_id=o2.id, menu_item_id=s2_items[2].id, name_snapshot=s2_items[2].name, unit_price=s2_items[2].price, quantity=1), # Jolly Spaghetti combo
            OrderItem(order_id=o2.id, menu_item_id=s2_items[3].id, name_snapshot=s2_items[3].name, unit_price=s2_items[3].price, quantity=1), # Yumburger
        ])
        db.add(DeliveryEvent(order_id=o2.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-18)))

        # ORDER 3: Status = "assigned" (Rider Ben assigned to Mang Inasal Gaisano Toril)
        o3 = Order(
            customer_id=cust3.id,
            store_id=store3.id,
            address_id=addr_bea_condo.id,
            status="assigned",
            subtotal=508.00,
            delivery_fee=45.00,
            total=553.00,
            route_distance_km=1.8,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=rider2.id,
            created_at=now_offset(-32),
        )
        db.add(o3)
        db.flush()
        db.add_all([
            OrderItem(order_id=o3.id, menu_item_id=s3_items[0].id, name_snapshot=s3_items[0].name, unit_price=s3_items[0].price, quantity=1), # PM1 Inasal Paa
            OrderItem(order_id=o3.id, menu_item_id=s3_items[2].id, name_snapshot=s3_items[2].name, unit_price=s3_items[2].price, quantity=1), # Pork BBQ
            OrderItem(order_id=o3.id, menu_item_id=s3_items[3].id, name_snapshot=s3_items[3].name, unit_price=s3_items[3].price, quantity=1), # Pork Sisig
            OrderItem(order_id=o3.id, menu_item_id=s3_items[4].id, name_snapshot=s3_items[4].name, unit_price=s3_items[4].price, quantity=1), # Halo-Halo
        ])
        db.add_all([
            DeliveryEvent(order_id=o3.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-28)),
            DeliveryEvent(order_id=o3.id, status="assigned", actor_id=admin.id, created_at=now_offset(-14)),
            AuditLog(actor_id=admin.id, action="order.assign", target_type="order", target_id=o3.id, reason="Nearest available rider in Crossing Toril", created_at=now_offset(-14)),
        ])

        # ORDER 4: Status = "picked_up" (Rider Caloy picked up from Kusina Dabaw Toril)
        o4 = Order(
            customer_id=cust1.id,
            store_id=store4.id,
            address_id=addr_maria_work.id,
            status="picked_up",
            subtotal=415.00,
            delivery_fee=45.00,
            total=460.00,
            route_distance_km=1.5,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=rider3.id,
            created_at=now_offset(-40),
        )
        db.add(o4)
        db.flush()
        db.add_all([
            OrderItem(order_id=o4.id, menu_item_id=s4_items[0].id, name_snapshot=s4_items[0].name, unit_price=s4_items[0].price, quantity=1), # Pancit Canton Bilao
            OrderItem(order_id=o4.id, menu_item_id=s4_items[1].id, name_snapshot=s4_items[1].name, unit_price=s4_items[1].price, quantity=1), # Lechon Kawali
        ])
        db.add_all([
            DeliveryEvent(order_id=o4.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-36)),
            DeliveryEvent(order_id=o4.id, status="assigned", actor_id=admin.id, created_at=now_offset(-28)),
            DeliveryEvent(order_id=o4.id, status="picked_up", actor_id=rider3.id, created_at=now_offset(-10)),
            LocationPoint(order_id=o4.id, rider_id=rider3.id, latitude=7.0198, longitude=125.5002, accuracy_m=4.8, captured_at=now_offset(-8)),
            LocationPoint(order_id=o4.id, rider_id=rider3.id, latitude=7.0182, longitude=125.5028, accuracy_m=3.9, captured_at=now_offset(-2)),
        ])

        # ORDER 5: Status = "on_the_way" (Rider Jun en route from Balamban Liempo Toril to Crossing Bayabas)
        o5 = Order(
            customer_id=cust1.id,
            store_id=store5.id,
            address_id=addr_maria_home.id,
            status="on_the_way",
            subtotal=430.00,
            delivery_fee=40.00,
            total=470.00,
            route_distance_km=1.3,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=rider1.id,
            created_at=now_offset(-28),
        )
        db.add(o5)
        db.flush()
        db.add_all([
            OrderItem(order_id=o5.id, menu_item_id=s5_items[0].id, name_snapshot=s5_items[0].name, unit_price=s5_items[0].price, quantity=1), # Balamban Liempo Slab
            OrderItem(order_id=o5.id, menu_item_id=s5_items[3].id, name_snapshot=s5_items[3].name, unit_price=s5_items[3].price, quantity=1), # Chorizo de Cebu
            OrderItem(order_id=o5.id, menu_item_id=s5_items[5].id, name_snapshot=s5_items[5].name, unit_price=s5_items[5].price, quantity=1), # Steamed Rice
        ])
        db.add_all([
            DeliveryEvent(order_id=o5.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-25)),
            DeliveryEvent(order_id=o5.id, status="assigned", actor_id=admin.id, created_at=now_offset(-20)),
            DeliveryEvent(order_id=o5.id, status="picked_up", actor_id=rider1.id, created_at=now_offset(-12)),
            DeliveryEvent(order_id=o5.id, status="on_the_way", actor_id=rider1.id, created_at=now_offset(-6)),
            LocationPoint(order_id=o5.id, rider_id=rider1.id, latitude=7.0205, longitude=125.4985, accuracy_m=4.0, captured_at=now_offset(-4)),
            LocationPoint(order_id=o5.id, rider_id=rider1.id, latitude=7.0225, longitude=125.5010, accuracy_m=3.5, captured_at=now_offset(-1)),
        ])

        # ORDER 6: Status = "delivered" (Delivered from Chowking Toril, COD ₱489 paid, 5-star review)
        o6 = Order(
            customer_id=cust1.id,
            store_id=store6.id,
            address_id=addr_maria_home.id,
            status="delivered",
            subtotal=449.00,
            delivery_fee=40.00,
            total=489.00,
            route_distance_km=1.1,
            payment_method="cash_on_delivery",
            payment_status="paid",
            rider_id=rider1.id,
            created_at=now_offset(-160),
        )
        db.add(o6)
        db.flush()
        db.add_all([
            OrderItem(order_id=o6.id, menu_item_id=s6_items[0].id, name_snapshot=s6_items[0].name, unit_price=s6_items[0].price, quantity=2), # Chao Fan Meals
            OrderItem(order_id=o6.id, menu_item_id=s6_items[4].id, name_snapshot=s6_items[4].name, unit_price=s6_items[4].price, quantity=1), # Halo-Halo Supreme
        ])
        db.add_all([
            DeliveryEvent(order_id=o6.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-155)),
            DeliveryEvent(order_id=o6.id, status="assigned", actor_id=admin.id, created_at=now_offset(-145)),
            DeliveryEvent(order_id=o6.id, status="picked_up", actor_id=rider1.id, created_at=now_offset(-130)),
            DeliveryEvent(order_id=o6.id, status="on_the_way", actor_id=rider1.id, created_at=now_offset(-120)),
            DeliveryEvent(order_id=o6.id, status="delivered", actor_id=rider1.id, created_at=now_offset(-100)),
            Feedback(order_id=o6.id, customer_id=cust1.id, rating=5, comment="Mainit pa ang Chao Fan at buo pa ang Halo-Halo pagdating sa Toril Crossing! Salamat Kuya Jun! ⭐⭐⭐⭐⭐", created_at=now_offset(-95)),
        ])

        # ORDER 7: Status = "cancelled" (Cancelled Kapewe Cafe order)
        o7 = Order(
            customer_id=cust2.id,
            store_id=store7.id,
            address_id=addr_juan_home.id,
            status="cancelled",
            subtotal=240.00,
            delivery_fee=40.00,
            total=280.00,
            route_distance_km=1.4,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=None,
            created_at=now_offset(-240),
        )
        db.add(o7)
        db.flush()
        db.add_all([
            OrderItem(order_id=o7.id, menu_item_id=s7_items[0].id, name_snapshot=s7_items[0].name, unit_price=s7_items[0].price, quantity=1), # Spanish Latte
            OrderItem(order_id=o7.id, menu_item_id=s7_items[4].id, name_snapshot=s7_items[4].name, unit_price=s7_items[4].price, quantity=1), # Truffle Fries
            DeliveryEvent(order_id=o7.id, status="cancelled", actor_id=admin.id, created_at=now_offset(-220)),
            AuditLog(actor_id=admin.id, action="order.cancel", target_type="order", target_id=o7.id, reason="Customer requested cancellation due to meeting reschedule in Toril", created_at=now_offset(-220)),
        ])

        db.commit()
        print("  ✓ 7 Orders created across Toril, Davao City lifecycle stages:")
        print("     1. 'pending'     (Penong's Toril Inato - Waiting for confirmation)")
        print("     2. 'confirmed'   (Jollibee Toril Crossing - Store accepted)")
        print("     3. 'assigned'    (Mang Inasal Gaisano Toril - Rider Ben assigned)")
        print("     4. 'picked_up'   (Kusina Dabaw Toril - Rider Caloy with live GPS)")
        print("     5. 'on_the_way'  (Balamban Liempo Toril - Rider Jun en route with live GPS)")
        print("     6. 'delivered'   (Chowking Toril McArthur - Delivered, COD ₱489 paid, 5-star rating)")
        print("     7. 'cancelled'   (Kapewe Cafe Bistro Toril - Cancelled with audit reason)")

    finally:
        db.close()
    print("\n✅ Toril, Davao City stores, menus, and orders seeded successfully!")


if __name__ == "__main__":
    seed()
