"""应用配置管理，基于 pydantic-settings 从环境变量读取。"""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """全局配置。"""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # 应用
    app_name: str = "TravelTranslator"
    app_env: str = "development"
    app_debug: bool = True
    app_host: str = "0.0.0.0"
    app_port: int = 8000

    # 数据库
    database_url: str = "sqlite+aiosqlite:///./data/traveltranslate.db"

    # 翻译引擎
    translation_engine: str = Field(default="mock", description="mock | anthropic | openai")
    anthropic_api_key: str = ""
    anthropic_model: str = "claude-opus-4-6"
    # OpenAI 兼容接口（可对接 OpenAI / DeepSeek / 通义 / Ollama / vLLM 等）
    openai_api_key: str = ""
    openai_base_url: str = "https://api.openai.com/v1"
    openai_model: str = "gpt-4o-mini"

    # CORS
    cors_origins: str = "http://localhost:5173,http://localhost:8080"

    # 日志
    log_level: str = "INFO"

    @property
    def cors_origin_list(self) -> list[str]:
        """解析逗号分隔的 CORS 来源。"""
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    """返回缓存的配置实例。"""
    return Settings()
