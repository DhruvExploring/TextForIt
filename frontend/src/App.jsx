import { useState } from 'react';
import './App.css';

function App() {
  const [url, setUrl] = useState('');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState('');
  const [error, setError] = useState('');

  const handleGenerate = async () => {
    if (!url) {
      setError('Please enter a valid YouTube URL');
      return;
    }
    
    setLoading(true);
    setError('');
    setResult('');

    try {
      // In production (EC2), Nginx serves the app so relative /api path works.
      // For local dev, set VITE_API_URL=http://127.0.0.1:8000 in frontend/.env.local
      const apiBase = import.meta.env.VITE_API_URL ?? '/api';
      const response = await fetch(`${apiBase}/transcript?link=${encodeURIComponent(url)}`);
      
      if (!response.ok) {
        throw new Error('Failed to fetch from server');
      }

      const data = await response.json();
      
      if (typeof data === 'string' && data.includes("Something went wrong")) {
        setError(data);
      } else {
        setResult(data);
      }
    } catch (err) {
      console.error(err);
      setError('An error occurred while connecting to the server. Is it running?');
    } finally {
      setLoading(false);
    }
  };

  // Basic function to render text with paragraphs (since it's a book chapter)
  const formatText = (text) => {
    return text.split('\n').map((paragraph, index) => {
      if (!paragraph.trim()) return null;
      
      // Check if it looks like a heading
      if (paragraph.startsWith('#')) {
        const level = (paragraph.match(/^#+/) || [''])[0].length;
        const textContent = paragraph.replace(/^#+\s*/, '');
        const HeadingTag = `h${Math.min(level, 6)}`;
        return <HeadingTag key={index}>{textContent}</HeadingTag>;
      }
      
      // Check if the text is wrapped in quotes
      if (paragraph.startsWith('"') && paragraph.endsWith('"')) {
        return <p key={index}><em>{paragraph}</em></p>;
      }

      return <p key={index}>{paragraph}</p>;
    });
  };

  return (
    <div className="container">
      <header className="header">
        <h1 className="title">TextForIt</h1>
        <p className="subtitle">Turn any YouTube video into an engaging book chapter.</p>
      </header>

      <section className="input-section">
        <div className="input-wrapper">
          <input
            type="text"
            className="yt-input"
            placeholder="Paste YouTube Video URL here..."
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            disabled={loading}
          />
        </div>
        
        <button 
          className="generate-btn" 
          onClick={handleGenerate}
          disabled={loading}
        >
          {loading ? (
            <>
              <span className="loader"></span> Generating Magic...
            </>
          ) : (
            'Generate Chapter'
          )}
        </button>

        {error && <div className="error-msg">{error}</div>}
      </section>

      {result && (
        <section className="result-section">
          {formatText(result)}
        </section>
      )}
    </div>
  );
}

export default App;
