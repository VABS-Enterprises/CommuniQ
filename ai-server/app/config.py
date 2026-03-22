import os

from dotenv import load_dotenv

load_dotenv()


class Settings:
    groq_api_key: str = os.getenv("GROQ_API_KEY", "")
    port: int = int(os.getenv("PORT", "8000"))

    def validate(self) -> None:
        if not self.groq_api_key:
            raise RuntimeError(
                "GROQ_API_KEY is not set. Add it to ai-server/.env and restart the server."
            )


settings = Settings()
