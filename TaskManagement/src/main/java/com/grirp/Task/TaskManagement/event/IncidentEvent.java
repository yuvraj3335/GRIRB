package com.grirp.Task.TaskManagement.event;

import java.time.LocalDateTime;
import java.util.List;

public class IncidentEvent {
    private Long incidentId;
    private String action; // e.g., "CREATED", "UPDATED"
    private List<String> incidentTypes; // e.g., ["fire", "crime", "ambulance"]
    private LocalDateTime timestamp;

    // Getters
    public Long getIncidentId() {
        return incidentId;
    }

    public String getAction() {
        return action;
    }

    public List<String> getIncidentTypes() {
        return incidentTypes;
    }

    public LocalDateTime getTimestamp() {
        return timestamp;
    }

    // Setters
    public void setIncidentId(Long incidentId) {
        this.incidentId = incidentId;
    }

    public void setAction(String action) {
        this.action = action;
    }

    public void setIncidentTypes(List<String> incidentTypes) {
        this.incidentTypes = incidentTypes;
    }

    public void setTimestamp(LocalDateTime timestamp) {
        this.timestamp = timestamp;
    }
}