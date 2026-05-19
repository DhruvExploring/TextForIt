def extract_video_id(link: str) -> str:
    """Extract YouTube video ID from short (youtu.be) or full watch URLs."""
    path = link.split("//")[-1]
    if "youtu.be/" in path:
        return path.split("youtu.be/")[1].split("?")[0]
    elif "v=" in path:
        return path.split("v=")[1].split("&")[0]
    raise ValueError(f"Cannot extract video ID from: {link}")


def get_llm_response(link: str) -> str:
    """Pass the YouTube video directly to Gemini and return a book-chapter rewrite."""
    from google import genai
    from google.genai import types
    from dotenv import load_dotenv
    load_dotenv()

    video_id = extract_video_id(link)
    youtube_url = f"https://www.youtube.com/watch?v={video_id}"

    prompt = (
        "Take this YouTube video and rewrite its content as a well-structured, "
        "engaging chapter of a book. Use vivid language, natural paragraph flow, "
        "section headings, and an authorial voice. "
        "Do NOT summarize — preserve all the ideas, examples, and explanations in full."
    )

    client = genai.Client()
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=[
            types.Part(file_data=types.FileData(file_uri=youtube_url)),
            types.Part(text=prompt),
        ]
    )
    return response.text
