from pydantic import BaseModel, field_validator


class TTSRequest(BaseModel):
    text: str
    voice: str | None = None

    @field_validator("text")
    @classmethod
    def validate_text(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Text must not be empty.")
        if len(v) > 2000:
            raise ValueError("Text too long. Maximum is 2000 characters for TTS.")
        return v
