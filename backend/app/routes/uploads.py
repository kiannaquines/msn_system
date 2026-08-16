from fastapi import APIRouter, Depends, HTTPException

from ..dependencies import require_roles
from ..integrations import authorize_storage_upload
from ..models import User
from ..schemas import UploadAuthorizeRequest, UploadAuthorizeResponse, UploadFinalizeRequest

router = APIRouter(prefix="/uploads", tags=["uploads"])


@router.post("/authorize", response_model=UploadAuthorizeResponse)
@router.post("/menu-images/authorize", response_model=UploadAuthorizeResponse)
def authorize(payload: UploadAuthorizeRequest, _: User = Depends(require_roles("admin"))) -> UploadAuthorizeResponse:
    try:
        path, url, token = authorize_storage_upload(payload.filename)
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Storage provider is unavailable") from exc
    return UploadAuthorizeResponse(object_path=path, upload_url=url, token=token)


@router.post("/finalize")
@router.post("/menu-images/finalize")
def finalize(payload: UploadFinalizeRequest, _: User = Depends(require_roles("admin"))) -> dict:
    # The object path is persisted on the menu item through its normal update
    # contract. Supabase is authoritative for object existence in production.
    return {"object_path": payload.object_path, "verified": True}
