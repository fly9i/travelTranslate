"""通用响应 schema。"""

from typing import Generic, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class ErrorResponse(BaseModel):
    """统一错误响应。"""

    error: str
    detail: str | None = None


class ListResponse(BaseModel, Generic[T]):
    """通用列表响应。"""

    items: list[T]
    total: int
