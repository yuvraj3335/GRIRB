package com.grirp.incidentmanagement.Event;

import lombok.Data;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class IncidentEvent {
    private Long incidentId;
    private String action;
    private List<String> incidentTypes; // ✅ Change String to List<String>
    private LocalDateTime timestamp;

    // Constructor
    public IncidentEvent(Long incidentId, String action, List<String> incidentTypes, LocalDateTime timestamp) {
        this.incidentId = incidentId;
        this.action = action;
        this.incidentTypes = incidentTypes;
        this.timestamp = timestamp;
    }

    // Getters and Setters
    public Long getIncidentId() { return incidentId; }
    public void setIncidentId(Long incidentId) { this.incidentId = incidentId; }

    public String getAction() { return action; }
    public void setAction(String action) { this.action = action; }

    public List<String> getIncidentTypes() { return incidentTypes; } // ✅ Use List<String>
    public void setIncidentTypes(List<String> incidentTypes) { this.incidentTypes = incidentTypes; }

    public LocalDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(LocalDateTime timestamp) { this.timestamp = timestamp; }
}
