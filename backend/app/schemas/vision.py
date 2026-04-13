"""Vision 场景理解接口的请求/响应 schema。"""

from pydantic import BaseModel, Field


class VisionDescribeRequest(BaseModel):
    """场景理解请求。"""

    ocr_texts: list[str] = Field(..., description="从图像中识别出的全部文字块（原文）")
    source_language: str = Field(default="auto", description="图片中文字的语言，auto 表示让模型自动判断")
    user_language: str = Field(default="zh", description="用户母语，用于输出说明")
    destination: str | None = Field(default=None, description="目的地国家/地区提示")
    hint: str | None = Field(default=None, description="用户对图片的额外提示，可选")


class VisionItem(BaseModel):
    """识别出的结构化条目（如菜单中的一道菜）。"""

    name: str = Field(..., description="条目名称（用用户母语）")
    original: str | None = Field(default=None, description="原文名称")
    description: str | None = Field(default=None, description="简短说明/食材")
    tags: list[str] = Field(default_factory=list, description="标签：辣度/过敏源/素食 等")
    recommendation: str | None = Field(default=None, description="推荐程度或注意事项")


class VisionDescribeResponse(BaseModel):
    """场景理解响应。"""

    scene_type: str = Field(..., description="menu / sign / receipt / document / other")
    summary: str = Field(..., description="整体说明（用户母语）")
    items: list[VisionItem] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list, description="旅行者需要注意的事项")
    engine: str = "mock"
