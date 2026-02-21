const MAX_TITLE_LEN: usize = 200;
const MAX_DESC_LEN: usize = 2000;

#[derive(Debug, Clone)]
pub struct Todo {
    pub id: u64,
    pub title: String,
    pub description: Option<String>,
    pub completed: bool,
}

#[derive(Debug)]
pub enum TodoError {
    NotFound,
    ValidationError(String),
}

impl Todo {
    // r[impl todo.create]
    pub fn new(title: &str, description: Option<&str>) -> Result<Self, TodoError> {
        // r[impl todo.validation.title]
        if title.is_empty() || title.len() > MAX_TITLE_LEN {
            return Err(TodoError::ValidationError(
                format!("Title must be between 1 and {} characters", MAX_TITLE_LEN),
            ));
        }

        // r[impl todo.validation.description]
        if let Some(desc) = description {
            if desc.len() > MAX_DESC_LEN {
                return Err(TodoError::ValidationError(
                    format!("Description must be at most {} characters", MAX_DESC_LEN),
                ));
            }
        }

        Ok(Self {
            id: 0,
            title: title.to_string(),
            description: description.map(String::from),
            completed: false,
        })
    }
}

pub struct TodoStore {
    items: Vec<Todo>,
    next_id: u64,
}

impl TodoStore {
    pub fn new() -> Self {
        Self {
            items: Vec::new(),
            next_id: 1,
        }
    }

    // r[impl todo.create]
    pub fn create(&mut self, title: &str, description: Option<&str>) -> Result<&Todo, TodoError> {
        let mut todo = Todo::new(title, description)?;
        todo.id = self.next_id;
        self.next_id += 1;
        self.items.push(todo);
        Ok(self.items.last().unwrap())
    }

    // r[impl todo.read]
    pub fn get(&self, id: u64) -> Result<&Todo, TodoError> {
        self.items
            .iter()
            .find(|t| t.id == id)
            .ok_or(TodoError::NotFound)
    }

    // r[impl todo.list]
    pub fn list(&self, completed: Option<bool>) -> Vec<&Todo> {
        self.items
            .iter()
            .filter(|t| completed.is_none_or(|c| t.completed == c))
            .collect()
    }

    // r[impl todo.update]
    pub fn update(
        &mut self,
        id: u64,
        title: Option<&str>,
        description: Option<Option<&str>>,
        completed: Option<bool>,
    ) -> Result<&Todo, TodoError> {
        let todo = self
            .items
            .iter_mut()
            .find(|t| t.id == id)
            .ok_or(TodoError::NotFound)?;

        if let Some(t) = title {
            // r[impl todo.validation.title]
            if t.is_empty() || t.len() > MAX_TITLE_LEN {
                return Err(TodoError::ValidationError(
                    format!("Title must be between 1 and {} characters", MAX_TITLE_LEN),
                ));
            }
            todo.title = t.to_string();
        }

        if let Some(d) = description {
            // r[impl todo.validation.description]
            if let Some(desc) = d {
                if desc.len() > MAX_DESC_LEN {
                    return Err(TodoError::ValidationError(
                        format!("Description must be at most {} characters", MAX_DESC_LEN),
                    ));
                }
            }
            todo.description = d.map(String::from);
        }

        if let Some(c) = completed {
            todo.completed = c;
        }

        Ok(todo)
    }

    // r[impl todo.delete]
    pub fn delete(&mut self, id: u64) -> Result<Todo, TodoError> {
        let pos = self
            .items
            .iter()
            .position(|t| t.id == id)
            .ok_or(TodoError::NotFound)?;
        Ok(self.items.remove(pos))
    }
}
