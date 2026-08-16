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
    print("📍 Seeding authentic Kabacan, Cotabato stores and delivery data...")
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
                full_name="Engr. Maria Corazon Aquino",
                phone="+639178880001",
                role="admin",
                is_active=True,
            )
            db.add(admin2)
        else:
            admin2.full_name = "Engr. Maria Corazon Aquino"
            admin2.password_hash = hash_password("Password123!")

        # Riders
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

        # Customers
        cust1 = db.scalar(select(User).where(User.email == "customer@mns.com"))
        if not cust1:
            cust1 = User(
                email="customer@mns.com",
                password_hash=hash_password("Password123!"),
                full_name="Maria Clara De Los Santos",
                phone="+639173334567",
                role="customer",
                is_active=True,
            )
            db.add(cust1)
        else:
            cust1.full_name = "Maria Clara De Los Santos"
            cust1.password_hash = hash_password("Password123!")

        cust2 = db.scalar(select(User).where(User.email == "customer.juan@mns.com"))
        if not cust2:
            cust2 = User(
                email="customer.juan@mns.com",
                password_hash=hash_password("Password123!"),
                full_name="Juan Miguel Bautista",
                phone="+639183335678",
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
        print("  ✓ Users active (Admin, 3 Riders, 3 Customers)")

        # =========================================================
        # 2. KABACAN SAVED CUSTOMER ADDRESSES
        # =========================================================
        db.query(Address).delete()
        addr_maria_home = Address(
            customer_id=cust1.id,
            label="Home (Villa Corazon)",
            line1="Block 7 Lot 12, Sampaguita St., Villa Corazon, Poblacion, Kabacan",
            latitude=7.1066,
            longitude=124.8292,
        )
        addr_maria_work = Address(
            customer_id=cust1.id,
            label="USM Main Campus",
            line1="College of Arts and Sciences Bldg., USM Avenue, Kabacan",
            latitude=7.1050,
            longitude=124.8190,
        )
        addr_juan_home = Address(
            customer_id=cust2.id,
            label="Bahay (Bayugan)",
            line1="Purok Rosal, Davao-Cotabato Highway, Brgy. Bayugan, Kabacan",
            latitude=7.1130,
            longitude=124.8290,
        )
        addr_bea_condo = Address(
            customer_id=cust3.id,
            label="Apartment (Mercado)",
            line1="Door 3, Mercado Street, Poblacion, Kabacan, Cotabato",
            latitude=7.1075,
            longitude=124.8245,
        )
        db.add_all([addr_maria_home, addr_maria_work, addr_juan_home, addr_bea_condo])
        db.flush()
        print("  ✓ Kabacan customer delivery addresses created")

        # =========================================================
        # 3. KABACAN GOOGLE MAPS STORES & PRODUCTS
        # =========================================================
        db.query(MenuItem).delete()
        db.query(Store).delete()

        # Store 1: Penong's Barbecue Seafood & Grill Kabacan
        store1 = Store(
            name="Penong's Barbecue Seafood & Grill",
            description="Davao-Cotabato National Highway, Brgy. Bayugan, Kabacan. Famous for Chicken Inato with unlimited rice, juicy pork BBQ, and sizzling seafood.",
            latitude=7.1125,
            longitude=124.8285,
            is_active=True,
        )
        db.add(store1)
        db.flush()

        s1_items = [
            MenuItem(store_id=store1.id, name="Chicken Inato Paa w/ Unlimited Rice", description="Quarter leg marinated in calamansi and annatto oil, grilled over charcoal.", category="Inato Meals", price=175.00, image_path="https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=400&q=80", is_available=True),
            MenuItem(store_id=store1.id, name="Chicken Inato Pecho w/ Unlimited Rice", description="Juicy breast and wing cut with sweet-savory basting sauce.", category="Inato Meals", price=185.00, image_path="https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=400&q=80", is_available=True),
            MenuItem(store_id=store1.id, name="Pork BBQ Skewers (3 Sticks)", description="Tender pork skewers with savory sweet glaze.", category="Grilled BBQ", price=145.00, image_path="https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=400&q=80", is_available=True),
            MenuItem(store_id=store1.id, name="Crispy Pata Special (Family)", description="Deep fried pork knuckle with crunchy skin and tender meat.", category="Popular", price=480.00, image_path="https://images.unsplash.com/photo-1544025162-d76694265947?w=400&q=80", is_available=True),
            MenuItem(store_id=store1.id, name="Sizzling Bulalo Steak", description="Tender beef shank served on a sizzling hot plate with mushroom gravy.", category="Popular", price=320.00, image_path="https://images.unsplash.com/photo-1558030006-450675393462?w=400&q=80", is_available=True),
            MenuItem(store_id=store1.id, name="Fresh Kinilaw na Tuna", description="Fresh raw tuna ceviche in vinegar, calamansi, ginger, and chili.", category="Seafood", price=210.00, image_path="https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=400&q=80", is_available=True),
            MenuItem(store_id=store1.id, name="House Calamansi Iced Tea (1L Pitcher)", description="Freshly squeezed calamansi cooler with honey.", category="Beverages", price=75.00, image_path="https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=400&q=80", is_available=True),
        ]
        db.add_all(s1_items)

        # Store 2: McMillan Kitchen & Catering
        store2 = Store(
            name="McMillan Kitchen & Cafe",
            description="Sunset Street, ABC Building (near USM Exit Gate), Poblacion, Kabacan. Cozy bistro offering creamy pasta, rice bowls, salpicao, and platters.",
            latitude=7.1082,
            longitude=124.8210,
            is_active=True,
        )
        db.add(store2)
        db.flush()

        s2_items = [
            MenuItem(store_id=store2.id, name="Creamy Carbonara Platter", description="Rich bacon mushroom fettuccine with garlic bread slices.", category="Pasta & Platters", price=180.00, image_path="https://images.unsplash.com/photo-1612874742237-6526221588e3?w=400&q=80", is_available=True),
            MenuItem(store_id=store2.id, name="Tender Beef Salpicao Rice Bowl", description="Pan-seared beef tenderloin cubes in garlic butter sauce with egg.", category="Rice Bowls", price=195.00, image_path="https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&q=80", is_available=True),
            MenuItem(store_id=store2.id, name="Crispy Chicken Fillet w/ Gravy", description="Golden fried fillet served with sweet corn and seasoned rice.", category="Rice Bowls", price=145.00, image_path="https://images.unsplash.com/photo-1562967914-608f82629710?w=400&q=80", is_available=True),
            MenuItem(store_id=store2.id, name="Sweet & Sour Fish Fillet Bowl", description="Crispy dory bites tossed in bell peppers and tangy sweet sauce.", category="Rice Bowls", price=160.00, image_path="https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400&q=80", is_available=True),
            MenuItem(store_id=store2.id, name="Triple Decker Club Sandwich w/ Fries", description="Ham, chicken, cheese, egg, lettuce with thick cut fries.", category="Snacks", price=135.00, image_path="https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=400&q=80", is_available=True),
            MenuItem(store_id=store2.id, name="Blueberry Cheesecake Slice", description="Creamy New York style cheesecake topped with blueberry compote.", category="Desserts", price=120.00, image_path="https://images.unsplash.com/photo-1533134242443-d4fd215305ad?w=400&q=80", is_available=True),
        ]
        db.add_all(s2_items)

        # Store 3: Bogs Bugoy Gastropub
        store3 = Store(
            name="Bogs Bugoy Gastropub",
            description="Mercado Street, Poblacion, Kabacan, Cotabato. Renowned for Korean Beef Bulgogi, Garlic Baked Scallops, and Sizzling Sisig.",
            latitude=7.1070,
            longitude=124.8250,
            is_active=True,
        )
        db.add(store3)
        db.flush()

        s3_items = [
            MenuItem(store_id=store3.id, name="Signature Beef Bulgogi Plate", description="Thinly sliced marinated beef in sweet soy sesame sauce with sesame seeds.", category="Chef Specials", price=240.00, image_path="https://images.unsplash.com/photo-1553163147-622ab57be1c7?w=400&q=80", is_available=True),
            MenuItem(store_id=store3.id, name="Garlic Butter Baked Scallops (8pcs)", description="Cheesy golden scallops baked with toasted garlic bits.", category="Seafood", price=260.00, image_path="https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80", is_available=True),
            MenuItem(store_id=store3.id, name="Crispy Garlic Fried Chicken (Half)", description="Double-fried chicken glazed with sweet garlic soy sauce.", category="Popular", price=220.00, image_path="https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=400&q=80", is_available=True),
            MenuItem(store_id=store3.id, name="Sizzling Pork Sisig w/ Fresh Egg", description="Crispy pork mask with onions, chili peppers, and calamansi.", category="Popular", price=190.00, image_path="https://images.unsplash.com/photo-1544025162-d76694265947?w=400&q=80", is_available=True),
            MenuItem(store_id=store3.id, name="Cheesy Supreme Nachos Platter", description="Tortilla chips loaded with seasoned beef, jalapeños, and cheese drizzle.", category="Pulutan & Snacks", price=180.00, image_path="https://images.unsplash.com/photo-1513456852971-30c0b8199d4d?w=400&q=80", is_available=True),
            MenuItem(store_id=store3.id, name="Blue Lagoon Mocktail Cooler (16oz)", description="Refreshing citrus blue curacao cooler with mint.", category="Beverages", price=85.00, image_path="https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=400&q=80", is_available=True),
        ]
        db.add_all(s3_items)

        # Store 4: Love BITE Restaurant
        store4 = Store(
            name="Love BITE Restaurant",
            description="LMD Building, Aglipay Street (in front of Aglipayan Church), Poblacion, Kabacan. Top-rated family dining for buttered chicken, seafood, and pancit.",
            latitude=7.1095,
            longitude=124.8240,
            is_active=True,
        )
        db.add(store4)
        db.flush()

        s4_items = [
            MenuItem(store_id=store4.id, name="Special Buttered Fried Chicken", description="Savory crispy chicken coated in aromatic melted butter glaze.", category="Popular", price=175.00, image_path="https://images.unsplash.com/photo-1569058242253-92a9c755a0ec?w=400&q=80", is_available=True),
            MenuItem(store_id=store4.id, name="Sweet & Spicy Buttered Shrimps", description="Fresh plump shrimps cooked in sweet chili garlic butter.", category="Seafood", price=240.00, image_path="https://images.unsplash.com/photo-1559737558-2453e1a0b168?w=400&q=80", is_available=True),
            MenuItem(store_id=store4.id, name="Crispy Lechon Kawali Silog Meal", description="Golden deep-fried pork belly with garlic sinangag and fried egg.", category="Silog Meals", price=150.00, image_path="https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=400&q=80", is_available=True),
            MenuItem(store_id=store4.id, name="Pancit Canton Guisado Fiesta Bilao", description="Stir-fried egg noodles with pork, liver, squid balls, and crisp vegetables.", category="Noodles", price=160.00, image_path="https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400&q=80", is_available=True),
            MenuItem(store_id=store4.id, name="Fresh Mixed Beef Chopsuey", description="Broccoli, cauliflower, bell peppers and beef in savory thick glaze.", category="Vegetables", price=150.00, image_path="https://images.unsplash.com/photo-1512058564366-18510be2db19?w=400&q=80", is_available=True),
            MenuItem(store_id=store4.id, name="Mango Graham Shake (16oz)", description="Fresh ripe mango shake layered with crushed honey graham and milk.", category="Beverages", price=75.00, image_path="https://images.unsplash.com/photo-1577805947697-89e18249d767?w=400&q=80", is_available=True),
        ]
        db.add_all(s4_items)

        # Store 5: Kabacan Pastil King & Native Delicacies
        store5 = Store(
            name="Kabacan Pastil King & Native Delicacies",
            description="USM Commercial Center, USM Avenue, Kabacan. Authentic Halal Maguindanaon chicken and beef kagikit pastil, fresh tinagtag, and native treats.",
            latitude=7.1055,
            longitude=124.8195,
            is_active=True,
        )
        db.add(store5)
        db.flush()

        s5_items = [
            MenuItem(store_id=store5.id, name="Special Chicken Kagikit Pastil (2 Packs)", description="Steamed fragrant rice topped with shredded savory chicken kagikit wrapped in banana leaf.", category="Pastil Staples", price=40.00, image_path="https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=400&q=80", is_available=True),
            MenuItem(store_id=store5.id, name="Spicy Shredded Beef Pastil (2 Packs)", description="Tender flaked beef kagikit with native chili oil over steamed rice.", category="Pastil Staples", price=50.00, image_path="https://images.unsplash.com/photo-1512058564366-18510be2db19?w=400&q=80", is_available=True),
            MenuItem(store_id=store5.id, name="Tuna Flakes Native Pastil (2 Packs)", description="Flaked yellowfin tuna with toasted onion and garlic flakes.", category="Pastil Staples", price=45.00, image_path="https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=400&q=80", is_available=True),
            MenuItem(store_id=store5.id, name="Hard Boiled Egg (Pastil Pairing)", description="Perfect accompaniment to traditional Maguindanao pastil.", category="Add-ons", price=15.00, image_path="https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=400&q=80", is_available=True),
            MenuItem(store_id=store5.id, name="Native Maguindanao Tinagtag Box", description="Crispy traditional fried rice flour delicacy with sugar syrup.", category="Native Delicacies", price=120.00, image_path="https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&q=80", is_available=True),
            MenuItem(store_id=store5.id, name="Fresh Cold Buko Juice (500ml)", description="Pure coconut water with tender buko meat shreds.", category="Beverages", price=35.00, image_path="https://images.unsplash.com/photo-1543362906-acfc16c67564?w=400&q=80", is_available=True),
        ]
        db.add_all(s5_items)

        # Store 6: Jollibee Kabacan Drive-Thru
        store6 = Store(
            name="Jollibee Kabacan Drive-Thru",
            description="National Highway corner USM Avenue, Poblacion, Kabacan. Philippines' favourite crispy Chickenjoy, Jolly Spaghetti, and classic Yumburgers.",
            latitude=7.1105,
            longitude=124.8260,
            is_active=True,
        )
        db.add(store6)
        db.flush()

        s6_items = [
            MenuItem(store_id=store6.id, name="1-pc Chickenjoy w/ Steamed Rice", description="Signature crispylicious, juicylicious fried chicken with savory gravy.", category="Chickenjoy", price=95.00, image_path="https://images.unsplash.com/photo-1569058242253-92a9c755a0ec?w=400&q=80", is_available=True),
            MenuItem(store_id=store6.id, name="2-pc Chickenjoy w/ Rice & Drink", description="Two pieces crispy fried chicken with steamed rice and regular drink.", category="Chickenjoy", price=189.00, image_path="https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=400&q=80", is_available=True),
            MenuItem(store_id=store6.id, name="Jolly Spaghetti w/ Yumburger Combo", description="Sweet-style spaghetti topped with grated cheese, hotdog slices, and beef burger.", category="Combos", price=135.00, image_path="https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=400&q=80", is_available=True),
            MenuItem(store_id=store6.id, name="Cheesy Classic Yumburger", description="100% pure beef patty with signature dressing and melted cheese.", category="Burgers", price=65.00, image_path="https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80", is_available=True),
            MenuItem(store_id=store6.id, name="1-pc Burger Steak w/ Rice & Mushroom Gravy", description="Beef patty simmered in mushroom gravy sauce over steamed rice.", category="Meals", price=70.00, image_path="https://images.unsplash.com/photo-1550547660-d9450f859349?w=400&q=80", is_available=True),
            MenuItem(store_id=store6.id, name="Peach Mango Pie (3-Pack Box)", description="Sweet mango and peach slices in a golden crispy golden crust.", category="Desserts", price=145.00, image_path="https://images.unsplash.com/photo-1519915028121-7d3463d20b13?w=400&q=80", is_available=True),
        ]
        db.add_all(s6_items)

        # Store 7: Don Macchiatos & Cafe Kabacan
        store7 = Store(
            name="Don Macchiatos & Cafe",
            description="USM Avenue, Brgy. Poblacion, Kabacan, Cotabato. Premium iced espresso coffee, Spanish lattes, matcha frappes, and freshly baked waffles.",
            latitude=7.1068,
            longitude=124.8215,
            is_active=True,
        )
        db.add(store7)
        db.flush()

        s7_items = [
            MenuItem(store_id=store7.id, name="Iced Caramel Macchiato (16oz)", description="Layered rich espresso with caramel drizzle and whole milk over ice.", category="Coffee Favorites", price=39.00, image_path="https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=400&q=80", is_available=True),
            MenuItem(store_id=store7.id, name="Iced Spanish Latte (16oz)", description="Espresso paired with condensed milk blend for a velvety sweet kick.", category="Coffee Favorites", price=39.00, image_path="https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400&q=80", is_available=True),
            MenuItem(store_id=store7.id, name="Dark Chocolate Java Chip (16oz)", description="Rich chocolate espresso cooler with blended chocolate chip bits.", category="Coffee Favorites", price=39.00, image_path="https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=400&q=80", is_available=True),
            MenuItem(store_id=store7.id, name="Strawberry Matcha Iced Latte (16oz)", description="Layered Japanese Uji matcha, fresh milk, and strawberry puree.", category="Specialty Drinks", price=49.00, image_path="https://images.unsplash.com/photo-1536256263959-770b48d82b0a?w=400&q=80", is_available=True),
            MenuItem(store_id=store7.id, name="Classic Golden Belgian Waffle", description="Freshly pressed crispy waffle with butter and maple syrup.", category="Waffles & Pastries", price=55.00, image_path="https://images.unsplash.com/photo-1562376552-0d160a2f238d?w=400&q=80", is_available=True),
        ]
        db.add_all(s7_items)
        db.flush()
        print("  ✓ 7 Kabacan Stores & 42 authentic menu items created")

        # =========================================================
        # 4. KABACAN ORDERS WITH REALISTIC STATUSES & GPS TRACKS
        # =========================================================
        # ORDER 1: Status = "pending" (Newly ordered by Maria from Penong's)
        o1 = Order(
            customer_id=cust1.id,
            store_id=store1.id,
            address_id=addr_maria_home.id,
            status="pending",
            subtotal=640.00,
            delivery_fee=45.00,
            total=685.00,
            route_distance_km=1.8,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=None,
            created_at=now_offset(-12),
        )
        db.add(o1)
        db.flush()
        db.add_all([
            OrderItem(order_id=o1.id, menu_item_id=s1_items[0].id, name_snapshot=s1_items[0].name, unit_price=s1_items[0].price, quantity=2), # Chicken Inato Paa
            OrderItem(order_id=o1.id, menu_item_id=s1_items[2].id, name_snapshot=s1_items[2].name, unit_price=s1_items[2].price, quantity=1), # Pork BBQ
            OrderItem(order_id=o1.id, menu_item_id=s1_items[6].id, name_snapshot=s1_items[6].name, unit_price=s1_items[6].price, quantity=1), # Calamansi Tea
        ])

        # ORDER 2: Status = "confirmed" (McMillan Kitchen accepted, waiting for rider assignment)
        o2 = Order(
            customer_id=cust2.id,
            store_id=store2.id,
            address_id=addr_juan_home.id,
            status="confirmed",
            subtotal=520.00,
            delivery_fee=50.00,
            total=570.00,
            route_distance_km=2.4,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=None,
            created_at=now_offset(-25),
        )
        db.add(o2)
        db.flush()
        db.add_all([
            OrderItem(order_id=o2.id, menu_item_id=s2_items[0].id, name_snapshot=s2_items[0].name, unit_price=s2_items[0].price, quantity=1), # Carbonara
            OrderItem(order_id=o2.id, menu_item_id=s2_items[1].id, name_snapshot=s2_items[1].name, unit_price=s2_items[1].price, quantity=1), # Beef Salpicao
            OrderItem(order_id=o2.id, menu_item_id=s2_items[4].id, name_snapshot=s2_items[4].name, unit_price=s2_items[4].price, quantity=1), # Club Sandwich
        ])
        db.add(DeliveryEvent(order_id=o2.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-20)))

        # ORDER 3: Status = "assigned" (Rider Ben assigned to Bogs Bugoy Gastropub)
        o3 = Order(
            customer_id=cust3.id,
            store_id=store3.id,
            address_id=addr_bea_condo.id,
            status="assigned",
            subtotal=690.00,
            delivery_fee=40.00,
            total=730.00,
            route_distance_km=1.2,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=rider2.id,
            created_at=now_offset(-35),
        )
        db.add(o3)
        db.flush()
        db.add_all([
            OrderItem(order_id=o3.id, menu_item_id=s3_items[0].id, name_snapshot=s3_items[0].name, unit_price=s3_items[0].price, quantity=1), # Beef Bulgogi
            OrderItem(order_id=o3.id, menu_item_id=s3_items[1].id, name_snapshot=s3_items[1].name, unit_price=s3_items[1].price, quantity=1), # Baked Scallops
            OrderItem(order_id=o3.id, menu_item_id=s3_items[3].id, name_snapshot=s3_items[3].name, unit_price=s3_items[3].price, quantity=1), # Pork Sisig
        ])
        db.add_all([
            DeliveryEvent(order_id=o3.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-30)),
            DeliveryEvent(order_id=o3.id, status="assigned", actor_id=admin.id, created_at=now_offset(-15)),
            AuditLog(actor_id=admin.id, action="order.assign", target_type="order", target_id=o3.id, reason="Nearest active rider in Poblacion Kabacan", created_at=now_offset(-15)),
        ])

        # ORDER 4: Status = "picked_up" (Rider Caloy picked up from Love BITE Restaurant)
        o4 = Order(
            customer_id=cust1.id,
            store_id=store4.id,
            address_id=addr_maria_work.id,
            status="picked_up",
            subtotal=485.00,
            delivery_fee=45.00,
            total=530.00,
            route_distance_km=1.6,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=rider3.id,
            created_at=now_offset(-45),
        )
        db.add(o4)
        db.flush()
        db.add_all([
            OrderItem(order_id=o4.id, menu_item_id=s4_items[0].id, name_snapshot=s4_items[0].name, unit_price=s4_items[0].price, quantity=1), # Buttered Chicken
            OrderItem(order_id=o4.id, menu_item_id=s4_items[2].id, name_snapshot=s4_items[2].name, unit_price=s4_items[2].price, quantity=1), # Lechon Kawali Silog
            OrderItem(order_id=o4.id, menu_item_id=s4_items[3].id, name_snapshot=s4_items[3].name, unit_price=s4_items[3].price, quantity=1), # Pancit Canton
        ])
        db.add_all([
            DeliveryEvent(order_id=o4.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-40)),
            DeliveryEvent(order_id=o4.id, status="assigned", actor_id=admin.id, created_at=now_offset(-32)),
            DeliveryEvent(order_id=o4.id, status="picked_up", actor_id=rider3.id, created_at=now_offset(-10)),
            LocationPoint(order_id=o4.id, rider_id=rider3.id, latitude=7.1092, longitude=124.8235, accuracy_m=5.0, captured_at=now_offset(-9)),
            LocationPoint(order_id=o4.id, rider_id=rider3.id, latitude=7.1075, longitude=124.8210, accuracy_m=4.2, captured_at=now_offset(-2)),
        ])

        # ORDER 5: Status = "on_the_way" (Rider Jun en route from Pastil King to Maria Clara)
        o5 = Order(
            customer_id=cust1.id,
            store_id=store5.id,
            address_id=addr_maria_home.id,
            status="on_the_way",
            subtotal=280.00,
            delivery_fee=40.00,
            total=320.00,
            route_distance_km=1.5,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=rider1.id,
            created_at=now_offset(-30),
        )
        db.add(o5)
        db.flush()
        db.add_all([
            OrderItem(order_id=o5.id, menu_item_id=s5_items[0].id, name_snapshot=s5_items[0].name, unit_price=s5_items[0].price, quantity=2), # Chicken Pastil (4 packs)
            OrderItem(order_id=o5.id, menu_item_id=s5_items[1].id, name_snapshot=s5_items[1].name, unit_price=s5_items[1].price, quantity=2), # Beef Pastil (4 packs)
            OrderItem(order_id=o5.id, menu_item_id=s5_items[3].id, name_snapshot=s5_items[3].name, unit_price=s5_items[3].price, quantity=2), # Boiled Egg
            OrderItem(order_id=o5.id, menu_item_id=s5_items[5].id, name_snapshot=s5_items[5].name, unit_price=s5_items[5].price, quantity=2), # Cold Buko Juice
        ])
        db.add_all([
            DeliveryEvent(order_id=o5.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-28)),
            DeliveryEvent(order_id=o5.id, status="assigned", actor_id=admin.id, created_at=now_offset(-22)),
            DeliveryEvent(order_id=o5.id, status="picked_up", actor_id=rider1.id, created_at=now_offset(-12)),
            DeliveryEvent(order_id=o5.id, status="on_the_way", actor_id=rider1.id, created_at=now_offset(-6)),
            LocationPoint(order_id=o5.id, rider_id=rider1.id, latitude=7.1060, longitude=124.8230, accuracy_m=4.0, captured_at=now_offset(-5)),
            LocationPoint(order_id=o5.id, rider_id=rider1.id, latitude=7.1064, longitude=124.8270, accuracy_m=3.5, captured_at=now_offset(-1)),
        ])

        # ORDER 6: Status = "delivered" (Delivered from Jollibee Kabacan, COD ₱564 paid, 5-star rating)
        o6 = Order(
            customer_id=cust1.id,
            store_id=store6.id,
            address_id=addr_maria_home.id,
            status="delivered",
            subtotal=519.00,
            delivery_fee=45.00,
            total=564.00,
            route_distance_km=1.9,
            payment_method="cash_on_delivery",
            payment_status="paid",
            rider_id=rider1.id,
            created_at=now_offset(-180),
        )
        db.add(o6)
        db.flush()
        db.add_all([
            OrderItem(order_id=o6.id, menu_item_id=s6_items[1].id, name_snapshot=s6_items[1].name, unit_price=s6_items[1].price, quantity=2), # 2-pc Chickenjoy Meals
            OrderItem(order_id=o6.id, menu_item_id=s6_items[5].id, name_snapshot=s6_items[5].name, unit_price=s6_items[5].price, quantity=1), # Peach Mango Pie Box
        ])
        db.add_all([
            DeliveryEvent(order_id=o6.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-175)),
            DeliveryEvent(order_id=o6.id, status="assigned", actor_id=admin.id, created_at=now_offset(-165)),
            DeliveryEvent(order_id=o6.id, status="picked_up", actor_id=rider1.id, created_at=now_offset(-150)),
            DeliveryEvent(order_id=o6.id, status="on_the_way", actor_id=rider1.id, created_at=now_offset(-140)),
            DeliveryEvent(order_id=o6.id, status="delivered", actor_id=rider1.id, created_at=now_offset(-120)),
            Feedback(order_id=o6.id, customer_id=cust1.id, rating=5, comment="Crispy at mainit pa ang Chickenjoy pagdating! Mabait si Kuya Jun rider. Salamat M&S! ⭐⭐⭐⭐⭐", created_at=now_offset(-110)),
        ])

        # ORDER 7: Status = "cancelled" (Cancelled Don Macchiatos order)
        o7 = Order(
            customer_id=cust2.id,
            store_id=store7.id,
            address_id=addr_juan_home.id,
            status="cancelled",
            subtotal=172.00,
            delivery_fee=40.00,
            total=212.00,
            route_distance_km=2.2,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=None,
            created_at=now_offset(-300),
        )
        db.add(o7)
        db.flush()
        db.add_all([
            OrderItem(order_id=o7.id, menu_item_id=s7_items[0].id, name_snapshot=s7_items[0].name, unit_price=s7_items[0].price, quantity=2), # Caramel Macchiato
            OrderItem(order_id=o7.id, menu_item_id=s7_items[4].id, name_snapshot=s7_items[4].name, unit_price=s7_items[4].price, quantity=1), # Belgian Waffle
            DeliveryEvent(order_id=o7.id, status="cancelled", actor_id=admin.id, created_at=now_offset(-280)),
            AuditLog(actor_id=admin.id, action="order.cancel", target_type="order", target_id=o7.id, reason="Customer called to cancel due to class schedule change at USM", created_at=now_offset(-280)),
        ])

        db.commit()
        print("  ✓ 7 Orders created across Kabacan lifecycle stages:")
        print("     1. 'pending'     (Penong's Chicken Inato - Waiting for confirmation)")
        print("     2. 'confirmed'   (McMillan Kitchen Pasta & Salpicao - Store accepted)")
        print("     3. 'assigned'    (Bogs Bugoy Gastropub Bulgogi - Rider Ben assigned)")
        print("     4. 'picked_up'   (Love BITE Buttered Chicken - Rider Caloy with live GPS)")
        print("     5. 'on_the_way'  (Kabacan Pastil King - Rider Jun en route with live GPS)")
        print("     6. 'delivered'   (Jollibee Kabacan - Delivered, COD ₱564 paid, 5-star rating)")
        print("     7. 'cancelled'   (Don Macchiatos - Cancelled with audit reason)")

    finally:
        db.close()
    print("\n✅ Kabacan, Cotabato stores, menus, and orders seeded successfully!")


if __name__ == "__main__":
    seed()
