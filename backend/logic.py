def get_yt_transcript(link:str) -> str:
    from youtube_transcript_api import YouTubeTranscriptApi
    link=link.split("//")[1]
    
    ytt_api = YouTubeTranscriptApi()
    try:
        video_id = link.split("=")[1]
        txt = ytt_api.fetch(video_id).snippets
    except Exception as e:
        video_id = link.split("/")[1]
        video_id = video_id.split("?")[0]
        txt = ytt_api.fetch(video_id).snippets
        
    text=""
    for i in txt:
        text+=i.text
    return text

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
