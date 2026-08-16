"""Initial M&S delivery schema.

Revision ID: 0001
"""
from alembic import op

from app.database import Base
from app import models  # noqa: F401

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        bind.exec_driver_sql("CREATE SCHEMA IF NOT EXISTS app")
        bind.exec_driver_sql("SET search_path TO app, public")
    Base.metadata.create_all(bind=bind)


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        bind.exec_driver_sql("DROP SCHEMA IF EXISTS app CASCADE")
    else:
        Base.metadata.drop_all(bind=bind)

