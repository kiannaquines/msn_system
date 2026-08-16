from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import get_settings


class Base(DeclarativeBase):
    pass


settings = get_settings()
engine_options: dict = {"pool_pre_ping": True}
if settings.database_url.startswith("sqlite"):
    engine_options["connect_args"] = {"check_same_thread": False}
else:
    # Supavisor transaction mode and serverless functions should not retain a
    # large process-local pool. PostgreSQL itself remains the source of truth.
    from sqlalchemy.pool import NullPool

    engine_options["poolclass"] = NullPool
    engine_options["connect_args"] = {"connect_timeout": 5, "prepare_threshold": None}
    # Qualify all application tables instead of relying on session-level
    # search_path, which is unsafe when Supavisor transaction pooling switches
    # backend connections between transactions.
    engine_options["execution_options"] = {"schema_translate_map": {None: "app"}}

engine = create_engine(settings.database_url, **engine_options)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
