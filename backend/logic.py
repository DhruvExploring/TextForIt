def get_yt_transcript(link: str) -> str:
    from youtube_transcript_api import YouTubeTranscriptApi
    from youtube_transcript_api.proxies import WebshareProxyConfig
    import os

    # Use Webshare proxy to bypass YouTube's AWS IP block.
    # Sign up free at https://proxy.webshare.io/ → Proxy → Username/Password
    # Then set these in backend/.env on your EC2.
    proxy_username = os.getenv("WEBSHARE_PROXY_USERNAME")
    proxy_password = os.getenv("WEBSHARE_PROXY_PASSWORD")

    if proxy_username and proxy_password:
        ytt_api = YouTubeTranscriptApi(
            proxy_config=WebshareProxyConfig(
                proxy_username=proxy_username,
                proxy_password=proxy_password,
            )
        )
    else:
        ytt_api = YouTubeTranscriptApi()  # works fine in local dev

    # Extract video ID from both youtu.be/ID and youtube.com/watch?v=ID formats
    path = link.split("//")[-1]          # strip https://
    if "youtu.be/" in path:
        video_id = path.split("youtu.be/")[1].split("?")[0]
    elif "v=" in path:
        video_id = path.split("v=")[1].split("&")[0]
    else:
        raise ValueError(f"Cannot extract video ID from: {link}")

    txt = ytt_api.fetch(video_id).snippets
    return "".join(i.text for i in txt)


def get_llm_response(text:str):
    from google import genai
    from dotenv import load_dotenv
    load_dotenv()

    prompt=f"Take this raw transcript and rewrite it as a well-structured, engaging chapter of a book. Use vivid language, natural paragraph flow, section headings, and an authorial voice. Do NOT summarize — preserve all the ideas, examples, and explanations in full.\n\n{text}"
    client = genai.Client()

    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=prompt
    )
    return response.text
