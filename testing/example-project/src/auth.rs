use std::time::{Duration, Instant};

#[derive(Debug)]
pub struct Session {
    pub token: String,
    pub expires_at: Instant,
}

#[derive(Debug)]
pub struct LoginError;

// r[impl auth.login]
pub fn login(username: &str, password: &str) -> Result<Session, LoginError> {
    // r[impl auth.login.validation]
    if username.is_empty() || password.is_empty() {
        return Err(LoginError);
    }

    // r[impl auth.session]
    Ok(Session {
        token: format!("tok_{}", username),
        expires_at: Instant::now() + Duration::from_secs(24 * 60 * 60),
    })
}

// r[impl auth.logout]
pub fn logout(_session: Session) {
    // Session is consumed (moved), effectively invalidating it
}

// r[impl auth.session.refresh]
pub fn refresh(session: &mut Session) {
    session.expires_at = Instant::now() + Duration::from_secs(24 * 60 * 60);
}

// Note: auth.login.rate_limit is not yet implemented
