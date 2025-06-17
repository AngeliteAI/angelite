#![feature(
    coroutines,
    coroutine_trait,
    gen_future,
    stmt_expr_attributes,
    trait_alias
)]

use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::collections::HashMap;
use std::io::{BufRead, BufReader};
use std::ops::{ControlFlow, Coroutine};
use std::pin::Pin;
use std::process::{Command, Stdio};

#[derive(Debug, Serialize, Deserialize)]
struct GeminiResponse {
    candidates: Vec<GeminiCandidate>,
    #[serde(default)]
    usage_metadata: Option<UsageMetadata>,
    #[serde(default)]
    model_version: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GeminiCandidate {
    content: GeminiContent,
    #[serde(default)]
    finish_reason: Option<String>,
    #[serde(default)]
    safety_ratings: Option<Vec<SafetyRating>>,
    #[serde(default)]
    index: Option<i32>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GeminiContent {
    parts: Vec<GeminiPart>,
    #[serde(default)]
    role: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GeminiPart {
    #[serde(default)]
    text: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct SafetyRating {
    category: String,
    probability: String,
    #[serde(default)]
    blocked: Option<bool>,
}

#[derive(Debug, Serialize, Deserialize)]
struct UsageMetadata {
    #[serde(default)]
    prompt_token_count: Option<i32>,
    #[serde(default)]
    candidates_token_count: Option<i32>,
    #[serde(default)]
    total_token_count: Option<i32>,
}

#[derive(Debug, Clone)]
pub enum GeminiError {
    HttpError(String),
    JsonParseError(String),
    CurlError(String),
    IoError(String),
    StreamError(String),
}

impl std::fmt::Display for GeminiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            GeminiError::HttpError(msg) => write!(f, "HTTP Error: {}", msg),
            GeminiError::JsonParseError(msg) => write!(f, "JSON Parse Error: {}", msg),
            GeminiError::CurlError(msg) => write!(f, "Curl Error: {}", msg),
            GeminiError::IoError(msg) => write!(f, "IO Error: {}", msg),
            GeminiError::StreamError(msg) => write!(f, "Stream Error: {}", msg),
        }
    }
}

impl std::error::Error for GeminiError {}

// Define a type for our streaming coroutine
pub trait StreamingCoroutine =
    std::ops::Coroutine<(), Yield = Result<String, GeminiError>, Return = Result<(), GeminiError>>;

pub struct GeminiClient {
    model_id: String,
    api_key: Option<String>,
    generation_config: HashMap<String, Value>,
}

impl GeminiClient {
    pub fn new(model_id: &str) -> Self {
        GeminiClient {
            model_id: model_id.to_string(),
            api_key: None,
            generation_config: HashMap::new(),
        }
    }

    pub fn with_api_key(mut self, api_key: &str) -> Self {
        self.api_key = Some(api_key.to_string());
        self
    }

    pub fn with_temperature(mut self, temperature: f32) -> Self {
        self.generation_config
            .insert("temperature".to_string(), json!(temperature));
        self
    }

    pub fn with_max_output_tokens(mut self, max_tokens: i32) -> Self {
        self.generation_config
            .insert("maxOutputTokens".to_string(), json!(max_tokens));
        self
    }

    pub fn with_top_p(mut self, top_p: f32) -> Self {
        self.generation_config
            .insert("topP".to_string(), json!(top_p));
        self
    }

    pub fn with_top_k(mut self, top_k: i32) -> Self {
        self.generation_config
            .insert("topK".to_string(), json!(top_k));
        self
    }

    // Non-streaming version (kept for compatibility)
    pub fn generate_content(&self, text: &str) -> Result<String, GeminiError> {
        // Get API key - either from the client or fail
        let api_key = match &self.api_key {
            Some(key) => key,
            None => {
                return Err(GeminiError::HttpError(
                    "API key is required for Gemini API".to_string(),
                ));
            }
        };

        // Use the correct URL format for non-streaming
        let url = format!(
            "https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent?key={}",
            self.model_id, api_key
        );

        // Prepare the request body
        let mut request_body = json!({
            "contents": [
                {
                    "role": "user",
                    "parts": [
                        {
                            "text": text
                        }
                    ]
                }
            ]
        });

        if !self.generation_config.is_empty() {
            let config = self
                .generation_config
                .iter()
                .map(|(k, v)| (k.clone(), v.clone()))
                .collect::<HashMap<_, _>>();
            request_body["generationConfig"] = json!(config);
        }

        let json_body = serde_json::to_string(&request_body)
            .map_err(|e| GeminiError::JsonParseError(e.to_string()))?;

        // Pass JSON data directly to curl
        let mut curl_cmd = Command::new("curl");

        curl_cmd
            .arg("-X")
            .arg("POST")
            .arg("-H")
            .arg("Content-Type: application/json; charset=utf-8")
            .arg("-d")
            .arg(json_body)
            .arg(url);

        let output = curl_cmd
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .map_err(|e| GeminiError::CurlError(e.to_string()))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(GeminiError::HttpError(format!(
                "Curl command failed: {}",
                stderr
            )));
        }

        let response_str = String::from_utf8_lossy(&output.stdout).to_string();

        let response: GeminiResponse = serde_json::from_str(&response_str).map_err(|e| {
            GeminiError::JsonParseError(format!(
                "Failed to parse response: {}. Response: {}",
                e, response_str
            ))
        })?;

        if response.candidates.is_empty() {
            return Err(GeminiError::HttpError("No candidates returned".to_string()));
        }

        if let Some(text) = &response.candidates[0].content.parts[0].text {
            Ok(text.clone())
        } else {
            Err(GeminiError::HttpError(
                "No text found in response".to_string(),
            ))
        }
    }

    // New streaming version that returns a coroutine the caller can drive
    pub fn generate_content_streaming<'a>(
        &self,
        text: &'a str,
    ) -> Box<dyn StreamingCoroutine + 'a> {
        // Clone the necessary data so the coroutine can own it
        let model_id = self.model_id.clone();
        let api_key = self.api_key.clone();
        let generation_config = self.generation_config.clone();

        // Create and return a coroutine
        Box::new(
            #[coroutine]
            move || {
                // Validate API key first
                let api_key = match api_key {
                    Some(key) => key,
                    None => {
                        yield Result::Err(GeminiError::HttpError(
                            "API key is required for Gemini API".to_string(),
                        ));
                        return Result::Err(GeminiError::HttpError(
                            "API key is required for Gemini API".to_string(),
                        ));
                    }
                };

                // Use the correct URL format for streaming
                let url = format!(
                    "https://generativelanguage.googleapis.com/v1beta/models/{}:streamGenerateContent?key={}",
                    model_id, api_key
                );

                // Prepare the request body
                let mut request_body = json!({
                    "contents": [
                        {
                            "role": "user",
                            "parts": [
                                {
                                    "text": text
                                }
                            ]
                        }
                    ]
                });

                if !generation_config.is_empty() {
                    let config = generation_config
                        .iter()
                        .map(|(k, v)| (k.clone(), v.clone()))
                        .collect::<HashMap<_, _>>();
                    request_body["generationConfig"] = json!(config);
                }

                let json_body = match serde_json::to_string(&request_body) {
                    Ok(body) => body,
                    Err(e) => {
                        yield Result::Err(GeminiError::JsonParseError(e.to_string()));
                        return Result::Err(GeminiError::JsonParseError(e.to_string()));
                    }
                };

                // Set up curl command for streaming
                let mut curl_cmd = Command::new("curl");

                curl_cmd
                    .arg("-X")
                    .arg("POST")
                    .arg("-H")
                    .arg("Content-Type: application/json; charset=utf-8")
                    .arg("-H")
                    .arg("Accept: text/event-stream") // Tell the API we want server-sent events
                    .arg("-N") // Important: disable buffering for streaming
                    .arg("-d")
                    .arg(json_body)
                    .arg(url);

                let mut child = match curl_cmd
                    .stdout(Stdio::piped())
                    .stderr(Stdio::piped())
                    .spawn()
                {
                    Ok(child) => child,
                    Err(e) => {
                        yield Result::Err(GeminiError::CurlError(e.to_string()));
                        return Result::Err(GeminiError::CurlError(e.to_string()));
                    }
                };

                let stdout = match child.stdout.take() {
                    Some(stdout) => stdout,
                    None => {
                        yield Result::Err(GeminiError::StreamError(
                            "Failed to capture stdout".to_string(),
                        ));
                        return Result::Err(GeminiError::StreamError(
                            "Failed to capture stdout".to_string(),
                        ));
                    }
                };

                // Process the stream line by line
                let reader = BufReader::new(stdout);
                let mut in_text_field = false;
                let mut current_text = String::new();
                let mut textbuf = String::new();

                for line_result in reader.lines() {
                    let line = match line_result {
                        Ok(line) => line,
                        Err(e) => {
                            yield Result::Err(GeminiError::StreamError(e.to_string()));
                            return Result::Err(GeminiError::StreamError(e.to_string()));
                        }
                    };

                    // Skip empty lines
                    if line.trim().is_empty() {
                        continue;
                    }

                    // Skip lone commas between objects
                    if line.trim() == "," {
                        continue;
                    }

                    // If we're already inside a text field from previous lines
                    if in_text_field {
                        // Find the end quote that isn't escaped
                        let mut i = 0;
                        let chars: Vec<char> = line.chars().collect();
                        let mut found_end = false;

                        while i < chars.len() {
                            if chars[i] == '"' {
                                // Check if this quote is escaped (preceded by odd number of backslashes)
                                let mut backslash_count = 0;
                                let mut j = i;
                                while j > 0 && chars[j - 1] == '\\' {
                                    backslash_count += 1;
                                    j -= 1;
                                }

                                if backslash_count % 2 == 0 {
                                    // This is a real end quote (not escaped)
                                    current_text.push_str(&line[..i]);

                                    // Yield the text
                                    yield Result::Ok(current_text.clone());

                                    // Reset state
                                    in_text_field = false;
                                    current_text.clear();
                                    found_end = true;

                                    // Process the rest of the line starting after this quote
                                    textbuf = line[i + 1..].to_string();
                                    break;
                                }
                            }
                            i += 1;
                        }

                        if !found_end {
                            // No end quote found, continue accumulating
                            current_text.push_str(&line);
                            current_text.push('\n');
                            continue;
                        }
                    }

                    // Look for new text fields
                    textbuf.push_str(&line);
                    let mut search_pos = 0;

                    while search_pos < textbuf.len() {
                        let start_marker = r#""text": ""#;
                        if let Some(start_idx) = textbuf[search_pos..].find(start_marker) {
                            let absolute_start = search_pos + start_idx;
                            let content_start = absolute_start + start_marker.len();

                            if content_start >= textbuf.len() {
                                // The start marker is at the end of the buffer, wait for more data
                                break;
                            }

                            // Find the closing quote that isn't escaped
                            let mut i = 0;
                            let chars: Vec<char> = textbuf[content_start..].chars().collect();
                            let mut found_end = false;

                            while i < chars.len() {
                                if chars[i] == '"' {
                                    // Check if this quote is escaped
                                    let mut backslash_count = 0;
                                    let mut j = i;
                                    while j > 0 && chars[j - 1] == '\\' {
                                        backslash_count += 1;
                                        j -= 1;
                                    }

                                    if backslash_count % 2 == 0 {
                                        // This is a real end quote
                                        let mut i = content_start;
                                        let mut escape = false;
                                        while i < textbuf.len() {
                                            let c = textbuf.as_bytes()[i];

                                            if c == b'\\' && !escape {
                                                escape = true;
                                            } else if c == b'"' && !escape {
                                                // Found unescaped quote
                                                break;
                                            } else {
                                                escape = false;
                                            }

                                            // Move to next character safely
                                            i += 1;
                                            while i < textbuf.len() && !textbuf.is_char_boundary(i)
                                            {
                                                i += 1;
                                            }
                                        }

                                        if i < textbuf.len() {
                                            let text = &textbuf[content_start..i];

                                            // Unescape the text
                                            let unescaped = unescape_string(&text).unwrap();

                                            // Yield the text
                                            yield Result::Ok(unescaped);

                                            // Update search position - make sure i is a valid boundary
                                            search_pos = i + 1;
                                            while search_pos < textbuf.len()
                                                && !textbuf.is_char_boundary(search_pos)
                                            {
                                                search_pos += 1;
                                            }

                                            found_end = true;
                                            break;
                                        }
                                    }
                                }
                                i += 1;
                            }

                            if !found_end {
                                // Text continues beyond this line
                                in_text_field = true;
                                current_text = textbuf[content_start..].to_string();
                                textbuf.clear();
                                break;
                            }
                        } else {
                            // No text field start found
                            break;
                        }
                    }

                    // Clear buffer if we're not in a text field and processed the line
                    if !in_text_field {
                        textbuf.clear();
                    }
                }

                // Wait for the child process to complete
                let status = match child.wait() {
                    Ok(status) => status,
                    Err(e) => {
                        yield Result::Err(GeminiError::CurlError(format!(
                            "Error waiting for curl process: {}",
                            e
                        )));
                        return Result::Err(GeminiError::CurlError(format!(
                            "Error waiting for curl process: {}",
                            e
                        )));
                    }
                };

                // Check if curl exited successfully
                if !status.success() {
                    let exit_code = status.code().unwrap_or(-1);
                    yield Result::Err(GeminiError::HttpError(format!(
                        "Curl command failed with exit code: {}",
                        exit_code
                    )));
                    return Result::Err(GeminiError::HttpError(format!(
                        "Curl command failed with exit code: {}",
                        exit_code
                    )));
                }

                Result::Ok(())
            },
        )
    }
}

// Helper function to extract text from response JSON
fn extract_text_from_response(json: &Value) -> Option<&str> {
    json.get("candidates")?
        .as_array()?
        .first()?
        .get("content")?
        .get("parts")?
        .as_array()?
        .first()?
        .get("text")?
        .as_str()
}

fn unescape_string(input: &str) -> Result<String, String> {
    let mut result = String::new();
    let mut chars = input.chars().peekable();

    while let Some(c) = chars.next() {
        if c == '\\' {
            match chars.next() {
                Some('u') => {
                    // Handle Unicode escape: \uXXXX
                    let mut code_point = 0u32;
                    let mut digit_count = 0;

                    // Check for the opening brace in \u{XXXX} format
                    let has_braces = chars.peek() == Some(&'{');
                    if has_braces {
                        chars.next(); // Consume the '{'
                    }

                    // Read 4 hex digits (or up to 6 if using braces)
                    let max_digits = if has_braces { 6 } else { 4 };

                    while digit_count < max_digits {
                        match chars.peek() {
                            Some(&c) if c.is_digit(16) => {
                                chars.next(); // Consume the digit
                                code_point = code_point * 16 + c.to_digit(16).unwrap();
                                digit_count += 1;
                            }
                            Some(&'}') if has_braces => {
                                chars.next(); // Consume the closing '}'
                                break;
                            }
                            _ if has_braces => {
                                return Err(format!(
                                    "Invalid Unicode escape sequence: missing closing brace"
                                ));
                            }
                            _ => break,
                        }
                    }

                    if digit_count == 0 {
                        return Err(format!("Invalid Unicode escape sequence: no digits"));
                    }

                    if has_braces && chars.peek() != Some(&'}') && digit_count > 0 {
                        return Err(format!(
                            "Invalid Unicode escape sequence: missing closing brace"
                        ));
                    }

                    match char::from_u32(code_point) {
                        Some(unicode_char) => result.push(unicode_char),
                        None => {
                            return Err(format!("Invalid Unicode code point: U+{:X}", code_point));
                        }
                    }
                }
                Some('n') => result.push('\n'),
                Some('r') => result.push('\r'),
                Some('t') => result.push('\t'),
                Some('\\') => result.push('\\'),
                Some('0') => result.push('\0'),
                Some('\'') => result.push('\''),
                Some('\"') => result.push('\"'),
                Some(c) => result.push(c), // Pass through unrecognized escapes
                None => return Err("Incomplete escape sequence".to_string()),
            }
        } else {
            result.push(c);
        }
    }

    Ok(result)
}
