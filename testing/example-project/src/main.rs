mod auth;
mod todo;

fn main() {
    println!("tracey example project");

    // r[impl auth.login]
    let session = auth::login("alice", "password123");
    println!("Login result: {:?}", session);

    // r[impl todo.create]
    let item = todo::Todo::new("Write tests", Some("Add unit tests for auth module"));
    println!("Created todo: {:?}", item);
}
