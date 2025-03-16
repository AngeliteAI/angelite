use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::collections::HashMap;
use std::fs;
use std::io::Write;
use std::path::Path;
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

#[derive(Debug)]
pub enum GeminiError {
    HttpError(String),
    JsonParseError(String),
    CurlError(String),
    IoError(String),
}

impl std::fmt::Display for GeminiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            GeminiError::HttpError(msg) => write!(f, "HTTP Error: {}", msg),
            GeminiError::JsonParseError(msg) => write!(f, "JSON Parse Error: {}", msg),
            GeminiError::CurlError(msg) => write!(f, "Curl Error: {}", msg),
            GeminiError::IoError(msg) => write!(f, "IO Error: {}", msg),
        }
    }
}

impl std::error::Error for GeminiError {}

pub struct GeminiClient {
    project_id: String,
    location: String,
    model_id: String,
    api_key: Option<String>,
    use_access_token: bool,
    generation_config: HashMap<String, Value>,
}

impl GeminiClient {
    pub fn new(project_id: &str, location: &str, model_id: &str) -> Self {
        GeminiClient {
            project_id: project_id.to_string(),
            location: location.to_string(),
            model_id: model_id.to_string(),
            api_key: None,
            use_access_token: true,
            generation_config: HashMap::new(),
        }
    }

    pub fn with_api_key(mut self, api_key: &str) -> Self {
        self.api_key = Some(api_key.to_string());
        self.use_access_token = false;
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

    pub fn generate_content(&self, text: &str) -> Result<String, GeminiError> {
        let url = format!(
            "https://{}-aiplatform.googleapis.com/v1/projects/{}/locations/{}/publishers/google/models/{}:generateContent",
            self.location, self.project_id, self.location, self.model_id
        );

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

        let temp_file = self.create_temp_file(&json_body)?;
        let temp_path = temp_file
            .to_str()
            .ok_or_else(|| GeminiError::IoError("Failed to get temporary file path".to_string()))?;

        let mut curl_cmd = Command::new("curl");

        curl_cmd
            .arg("-X")
            .arg("POST")
            .arg("-H")
            .arg("Content-Type: application/json; charset=utf-8");

        if let Some(api_key) = &self.api_key {
            curl_cmd
                .arg("-H")
                .arg(format!("x-goog-api-key: {}", api_key));
        } else if self.use_access_token {
            // Get access token using gcloud
            let output = Command::new("gcloud")
                .args(["auth", "print-access-token"])
                .output()
                .map_err(|e| {
                    GeminiError::CurlError(format!("Failed to get access token: {}", e))
                })?;

            if !output.status.success() {
                return Err(GeminiError::CurlError(
                    "Failed to get access token".to_string(),
                ));
            }

            let token = String::from_utf8_lossy(&output.stdout).trim().to_string();
            curl_cmd
                .arg("-H")
                .arg(format!("Authorization: Bearer {}", token));
        }

        curl_cmd.arg("-d").arg(format!("@{}", temp_path)).arg(url);

        let output = curl_cmd
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .map_err(|e| GeminiError::CurlError(e.to_string()))?;

        // Clean up temp file
        fs::remove_file(temp_file)
            .map_err(|e| GeminiError::IoError(format!("Failed to remove temp file: {}", e)))?;

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

    fn create_temp_file(&self, content: &str) -> Result<std::path::PathBuf, GeminiError> {
        let temp_dir = std::env::temp_dir();
        let file_name = format!(
            "gemini_request_{}.json",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map_err(|e| GeminiError::IoError(e.to_string()))?
                .as_millis()
        );

        let file_path = temp_dir.join(file_name);

        let mut file = fs::File::create(&file_path)
            .map_err(|e| GeminiError::IoError(format!("Failed to create temp file: {}", e)))?;

        file.write_all(content.as_bytes())
            .map_err(|e| GeminiError::IoError(format!("Failed to write to temp file: {}", e)))?;

        Ok(file_path)
    }
}
