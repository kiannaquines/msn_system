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
    print("🇵🇭 Seeding authentic Filipino delivery data...")
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
        # Admin
        admin = db.scalar(select(User).where(User.email == "admin@mns.com"))
        if not admin:
            admin = User(
                email="admin@mns.com",
                password_hash=hash_password("Password123!"),
                full_name="Engr. Maria Corazon Aquino",
                phone="+639178880001",
                role="admin",
                is_active=True,
            )
            db.add(admin)
        else:
            admin.full_name = "Engr. Maria Corazon Aquino"
            admin.password_hash = hash_password("Password123!")

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
        print("  ✓ Users created (Admin, 3 Riders, 3 Customers)")

        # =========================================================
        # 2. CUSTOMER ADDRESSES
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
            label="Office (USM)",
            line1="2F College of Arts & Sciences, USM Main Campus, Kabacan",
            latitude=7.1125,
            longitude=124.8350,
        )
        addr_juan_home = Address(
            customer_id=cust2.id,
            label="Bahay",
            line1="Purok Rosal, National Highway, Brgy. Katidtuan, Kabacan",
            latitude=7.1180,
            longitude=124.8210,
        )
        addr_bea_condo = Address(
            customer_id=cust3.id,
            label="Apartment",
            line1="Unit 304, Green Heights Residences, Agusan St., Poblacion, Kabacan",
            latitude=7.1035,
            longitude=124.8320,
        )
        db.add_all([addr_maria_home, addr_maria_work, addr_juan_home, addr_bea_condo])
        db.flush()
        print("  ✓ Saved customer delivery addresses created")

        # =========================================================
        # 3. AUTHENTIC FILIPINO STORES & MENU ITEMS
        # =========================================================
        db.query(MenuItem).delete()
        db.query(Store).delete()

        # Store 1: Inasal & Ihaw-Ihaw
        store1 = Store(
            name="Manok ni San Pedro Inasal & Ihaw-Ihaw",
            description="Bantog sa authentic Bacolod-style chicken inasal, juicy liempo, at unli-garlic rice.",
            latitude=7.1080,
            longitude=124.8310,
            is_active=True,
        )
        db.add(store1)
        db.flush()

        s1_items = [
            MenuItem(store_id=store1.id, name="Paa Large Chicken Inasal w/ Garlic Rice & Atchara", description="Quarter leg marinated in calamansi, sinamak, and annatto oil.", category="Inasal Meals", price=185.00, is_available=True),
            MenuItem(store_id=store1.id, name="Pecho Pak Inasal w/ Garlic Rice", description="Juicy breast and wing cut grilled over charcoal.", category="Inasal Meals", price=199.00, is_available=True),
            MenuItem(store_id=store1.id, name="Inihaw na Pork Liempo (300g)", description="Tender pork belly basted with sweet-savory glaze.", category="Grilled Specialties", price=245.00, is_available=True),
            MenuItem(store_id=store1.id, name="Sizzling Pork Sisig Special w/ Fresh Egg", description="Crispy pork mask & liver with chili and calamansi.", category="Popular", price=230.00, is_available=True),
            MenuItem(store_id=store1.id, name="Extra Sinangag Garlic Butter Rice", description="Fried rice tossed in fragrant toasted garlic.", category="Sides", price=45.00, is_available=True),
            MenuItem(store_id=store1.id, name="Samalamig Sago't Gulaman (16oz)", description="Classic brown sugar cooler with sago pearls and jelly.", category="Drinks", price=55.00, is_available=True),
        ]
        db.add_all(s1_items)

        # Store 2: Carinderia / Lutong Bahay
        store2 = Store(
            name="Nanay Bebeng's Carinderia & Lutong Bahay",
            description="Araw-araw sariwa at masasarap na ulam: Sinigang, Bulalo, Kare-Kare, at Lechon Kawali.",
            latitude=7.1055,
            longitude=124.8265,
            is_active=True,
        )
        db.add(store2)
        db.flush()

        s2_items = [
            MenuItem(store_id=store2.id, name="Special Beef Bulalo Batangas", description="Rich beef shank bone marrow soup with sweet corn and pechay.", category="Sabaw Specialties", price=320.00, is_available=True),
            MenuItem(store_id=store2.id, name="Sinigang na Baboy sa Gabi & Sampalok", description="Sour tamarind pork ribs stew with kangkong and radish.", category="Sabaw Specialties", price=220.00, is_available=True),
            MenuItem(store_id=store2.id, name="Kare-Kareng Baka w/ Barrio Bagoong", description="Rich peanut sauce stew with tender beef, tripe, and eggplant.", category="Lutong Bahay", price=280.00, is_available=True),
            MenuItem(store_id=store2.id, name="Crispy Pork Lechon Kawali (250g)", description="Deep-fried pork belly with Mang Tomas sauce.", category="Popular", price=250.00, is_available=True),
            MenuItem(store_id=store2.id, name="Tortang Talong w/ Giniling na Baboy", description="Smoky grilled eggplant omelette stuffed with ground pork.", category="Gulay at Torta", price=130.00, is_available=True),
            MenuItem(store_id=store2.id, name="Kanin (Steamed Pandan Rice)", description="Fragrant white rice.", category="Sides", price=30.00, is_available=True),
        ]
        db.add_all(s2_items)

        # Store 3: Kape & Kakanin
        store3 = Store(
            name="Kanto Kape & Kakanin Republic",
            description="Artisan Batangas Barako coffee, Iced Spanish Latte, mainit na Bibingka, at Puto Bumbong.",
            latitude=7.1038,
            longitude=124.8335,
            is_active=True,
        )
        db.add(store3)
        db.flush()

        s3_items = [
            MenuItem(store_id=store3.id, name="Iced Creamy Spanish Latte (16oz)", description="Fresh espresso with sweet milk blend over ice.", category="Kape", price=145.00, is_available=True),
            MenuItem(store_id=store3.id, name="Hot Kapeng Barako Batangas (12oz)", description="Traditional dark roast drip coffee from Lipa, Batangas.", category="Kape", price=90.00, is_available=True),
            MenuItem(store_id=store3.id, name="Special Bibingka w/ Salted Egg & Kesong Puti", description="Freshly baked rice cake topped with butter and grated coconut.", category="Kakanin", price=135.00, is_available=True),
            MenuItem(store_id=store3.id, name="Puto Bumbong (2 pcs) w/ Niyog & Muscovado", description="Steamed purple rice treat topped with golden butter.", category="Kakanin", price=115.00, is_available=True),
            MenuItem(store_id=store3.id, name="Leche Flan Special (1 Llanera)", description="Smooth caramel custard flan made from pure egg yolks.", category="Desserts", price=165.00, is_available=True),
        ]
        db.add_all(s3_items)

        # Store 4: Bakery & Merienda
        store4 = Store(
            name="Aling Nena's Panaderya & Merienda",
            description="Bagong hango sa pugon na pandesal, ensaymada, merienda pancit, at lumpiang sariwa.",
            latitude=7.1110,
            longitude=124.8280,
            is_active=True,
        )
        db.add(store4)
        db.flush()

        s4_items = [
            MenuItem(store_id=store4.id, name="Pancit Canton Fiesta Bilao (Good for 2-3)", description="Stir-fried yellow noodles with pork, chicken liver, and crisp veggies.", category="Merienda", price=210.00, is_available=True),
            MenuItem(store_id=store4.id, name="Fresh Lumpiang Ubod (2 pcs)", description="Heart of palm spring rolls with sweet peanut sauce.", category="Merienda", price=140.00, is_available=True),
            MenuItem(store_id=store4.id, name="Ube Cheese Pandesal (Box of 6)", description="Soft purple yam bread with savory melted cheddar cheese filling.", category="Bakery", price=150.00, is_available=True),
            MenuItem(store_id=store4.id, name="Special Queso de Bola Ensaymada", description="Brioche bun lathered in butter and grated Dutch cheese.", category="Bakery", price=85.00, is_available=True),
        ]
        db.add_all(s4_items)
        db.flush()
        print("  ✓ 4 Filipino Stores & 21 authentic menu items created")

        # =========================================================
        # 4. ORDERS WITH VARIOUS REALISTIC STATUSES
        # =========================================================
        # ORDER 1: Status = "pending" (Newly ordered by Maria, waiting for admin/store confirm)
        o1 = Order(
            customer_id=cust1.id,
            store_id=store1.id,
            address_id=addr_maria_home.id,
            status="pending",
            subtotal=645.00,
            delivery_fee=55.00,
            total=700.00,
            route_distance_km=2.1,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=None,
            created_at=now_offset(-12),
        )
        db.add(o1)
        db.flush()
        db.add_all([
            OrderItem(order_id=o1.id, menu_item_id=s1_items[0].id, name_snapshot=s1_items[0].name, unit_price=s1_items[0].price, quantity=2),
            OrderItem(order_id=o1.id, menu_item_id=s1_items[3].id, name_snapshot=s1_items[3].name, unit_price=s1_items[3].price, quantity=1),
            OrderItem(order_id=o1.id, menu_item_id=s1_items[4].id, name_snapshot=s1_items[4].name, unit_price=s1_items[4].price, quantity=1),
        ])

        # ORDER 2: Status = "confirmed" (Store accepted, waiting for rider assignment)
        o2 = Order(
            customer_id=cust2.id,
            store_id=store2.id,
            address_id=addr_juan_home.id,
            status="confirmed",
            subtotal=590.00,
            delivery_fee=65.00,
            total=655.00,
            route_distance_km=3.4,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=None,
            created_at=now_offset(-25),
        )
        db.add(o2)
        db.flush()
        db.add_all([
            OrderItem(order_id=o2.id, menu_item_id=s2_items[1].id, name_snapshot=s2_items[1].name, unit_price=s2_items[1].price, quantity=1), # Sinigang
            OrderItem(order_id=o2.id, menu_item_id=s2_items[3].id, name_snapshot=s2_items[3].name, unit_price=s2_items[3].price, quantity=1), # Lechon Kawali
            OrderItem(order_id=o2.id, menu_item_id=s2_items[5].id, name_snapshot=s2_items[5].name, unit_price=s2_items[5].price, quantity=4), # Rice
        ])
        db.add(DeliveryEvent(order_id=o2.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-20)))

        # ORDER 3: Status = "assigned" (Rider Ben assigned, heading to store)
        o3 = Order(
            customer_id=cust3.id,
            store_id=store3.id,
            address_id=addr_bea_condo.id,
            status="assigned",
            subtotal=540.00,
            delivery_fee=50.00,
            total=590.00,
            route_distance_km=1.5,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=rider2.id,
            created_at=now_offset(-35),
        )
        db.add(o3)
        db.flush()
        db.add_all([
            OrderItem(order_id=o3.id, menu_item_id=s3_items[0].id, name_snapshot=s3_items[0].name, unit_price=s3_items[0].price, quantity=2), # Spanish Latte
            OrderItem(order_id=o3.id, menu_item_id=s3_items[2].id, name_snapshot=s3_items[2].name, unit_price=s3_items[2].price, quantity=1), # Bibingka
            OrderItem(order_id=o3.id, menu_item_id=s3_items[4].id, name_snapshot=s3_items[4].name, unit_price=s3_items[4].price, quantity=1), # Leche Flan
        ])
        db.add_all([
            DeliveryEvent(order_id=o3.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-30)),
            DeliveryEvent(order_id=o3.id, status="assigned", actor_id=admin.id, created_at=now_offset(-15)),
            AuditLog(actor_id=admin.id, action="order.assign", target_type="order", target_id=o3.id, reason="Nearest active rider in Poblacion area", created_at=now_offset(-15)),
        ])

        # ORDER 4: Status = "picked_up" (Rider Caloy picked up from Aling Nena's Panaderya)
        o4 = Order(
            customer_id=cust1.id,
            store_id=store4.id,
            address_id=addr_maria_work.id,
            status="picked_up",
            subtotal=500.00,
            delivery_fee=55.00,
            total=555.00,
            route_distance_km=2.2,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=rider3.id,
            created_at=now_offset(-45),
        )
        db.add(o4)
        db.flush()
        db.add_all([
            OrderItem(order_id=o4.id, menu_item_id=s4_items[0].id, name_snapshot=s4_items[0].name, unit_price=s4_items[0].price, quantity=1), # Pancit Canton
            OrderItem(order_id=o4.id, menu_item_id=s4_items[1].id, name_snapshot=s4_items[1].name, unit_price=s4_items[1].price, quantity=1), # Lumpiang Ubod
            OrderItem(order_id=o4.id, menu_item_id=s4_items[2].id, name_snapshot=s4_items[2].name, unit_price=s4_items[2].price, quantity=1), # Ube Pandesal
        ])
        db.add_all([
            DeliveryEvent(order_id=o4.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-40)),
            DeliveryEvent(order_id=o4.id, status="assigned", actor_id=admin.id, created_at=now_offset(-32)),
            DeliveryEvent(order_id=o4.id, status="picked_up", actor_id=rider3.id, created_at=now_offset(-10)),
            LocationPoint(order_id=o4.id, rider_id=rider3.id, latitude=7.1112, longitude=124.8282, accuracy_m=5.0, captured_at=now_offset(-9)),
            LocationPoint(order_id=o4.id, rider_id=rider3.id, latitude=7.1118, longitude=124.8305, accuracy_m=4.2, captured_at=now_offset(-2)),
        ])

        # ORDER 5: Status = "on_the_way" (Rider Jun en route to Maria Clara)
        o5 = Order(
            customer_id=cust1.id,
            store_id=store1.id,
            address_id=addr_maria_home.id,
            status="on_the_way",
            subtotal=544.00,
            delivery_fee=55.00,
            total=599.00,
            route_distance_km=2.1,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=rider1.id,
            created_at=now_offset(-30),
        )
        db.add(o5)
        db.flush()
        db.add_all([
            OrderItem(order_id=o5.id, menu_item_id=s1_items[1].id, name_snapshot=s1_items[1].name, unit_price=s1_items[1].price, quantity=2), # Pecho Pak
            OrderItem(order_id=o5.id, menu_item_id=s1_items[4].id, name_snapshot=s1_items[4].name, unit_price=s1_items[4].price, quantity=2), # Sinangag
            OrderItem(order_id=o5.id, menu_item_id=s1_items[5].id, name_snapshot=s1_items[5].name, unit_price=s1_items[5].price, quantity=1), # Sago't Gulaman
        ])
        db.add_all([
            DeliveryEvent(order_id=o5.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-28)),
            DeliveryEvent(order_id=o5.id, status="assigned", actor_id=admin.id, created_at=now_offset(-22)),
            DeliveryEvent(order_id=o5.id, status="picked_up", actor_id=rider1.id, created_at=now_offset(-12)),
            DeliveryEvent(order_id=o5.id, status="on_the_way", actor_id=rider1.id, created_at=now_offset(-6)),
            LocationPoint(order_id=o5.id, rider_id=rider1.id, latitude=7.1075, longitude=124.8300, accuracy_m=4.0, captured_at=now_offset(-5)),
            LocationPoint(order_id=o5.id, rider_id=rider1.id, latitude=7.1069, longitude=124.8295, accuracy_m=3.5, captured_at=now_offset(-1)),
        ])

        # ORDER 6: Status = "delivered" (Delivered, COD ₱920 collected, Customer rated 5 stars)
        o6 = Order(
            customer_id=cust1.id,
            store_id=store2.id,
            address_id=addr_maria_home.id,
            status="delivered",
            subtotal=860.00,
            delivery_fee=60.00,
            total=920.00,
            route_distance_km=2.8,
            payment_method="cash_on_delivery",
            payment_status="paid",
            rider_id=rider1.id,
            created_at=now_offset(-180),
        )
        db.add(o6)
        db.flush()
        db.add_all([
            OrderItem(order_id=o6.id, menu_item_id=s2_items[0].id, name_snapshot=s2_items[0].name, unit_price=s2_items[0].price, quantity=1), # Bulalo
            OrderItem(order_id=o6.id, menu_item_id=s2_items[2].id, name_snapshot=s2_items[2].name, unit_price=s2_items[2].price, quantity=1), # Kare-Kare
            OrderItem(order_id=o6.id, menu_item_id=s2_items[4].id, name_snapshot=s2_items[4].name, unit_price=s2_items[4].price, quantity=2), # Tortang Talong
        ])
        db.add_all([
            DeliveryEvent(order_id=o6.id, status="confirmed", actor_id=admin.id, created_at=now_offset(-175)),
            DeliveryEvent(order_id=o6.id, status="assigned", actor_id=admin.id, created_at=now_offset(-165)),
            DeliveryEvent(order_id=o6.id, status="picked_up", actor_id=rider1.id, created_at=now_offset(-150)),
            DeliveryEvent(order_id=o6.id, status="on_the_way", actor_id=rider1.id, created_at=now_offset(-140)),
            DeliveryEvent(order_id=o6.id, status="delivered", actor_id=rider1.id, created_at=now_offset(-120)),
            Feedback(order_id=o6.id, customer_id=cust1.id, rating=5, comment="Napakainit pa ng Bulalo at malinamnam ang Kare-Kare! Salamat Kuya Jun sa maingat na paghatid! ⭐⭐⭐⭐⭐", created_at=now_offset(-110)),
        ])

        # ORDER 7: Status = "cancelled" (Customer requested cancellation before prep)
        o7 = Order(
            customer_id=cust2.id,
            store_id=store1.id,
            address_id=addr_juan_home.id,
            status="cancelled",
            subtotal=245.00,
            delivery_fee=55.00,
            total=300.00,
            route_distance_km=2.0,
            payment_method="cash_on_delivery",
            payment_status="unpaid",
            rider_id=None,
            created_at=now_offset(-300),
        )
        db.add(o7)
        db.flush()
        db.add_all([
            OrderItem(order_id=o7.id, menu_item_id=s1_items[2].id, name_snapshot=s1_items[2].name, unit_price=s1_items[2].price, quantity=1), # Liempo
            DeliveryEvent(order_id=o7.id, status="cancelled", actor_id=admin.id, created_at=now_offset(-280)),
            AuditLog(actor_id=admin.id, action="order.cancel", target_type="order", target_id=o7.id, reason="Customer called to cancel due to emergency change of plans", created_at=now_offset(-280)),
        ])

        db.commit()
        print("  ✓ 7 Orders created spanning all lifecycle stages:")
        print("     1. 'pending'     (Waiting for admin confirmation)")
        print("     2. 'confirmed'   (Store accepted, waiting for rider assignment)")
        print("     3. 'assigned'    (Rider Ben assigned)")
        print("     4. 'picked_up'   (Rider Caloy picked up, with live GPS points)")
        print("     5. 'on_the_way'  (Rider Jun en route, with live GPS points)")
        print("     6. 'delivered'   (Delivered, COD ₱920 paid, 5-star feedback)")
        print("     7. 'cancelled'   (Cancelled with recorded audit reason)")

    finally:
        db.close()
    print("\n✅ Realistic Filipino seed data generated successfully!")


if __name__ == "__main__":
    seed()
