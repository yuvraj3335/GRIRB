package com.grirp.incidentmanagement.DTO;

import lombok.Data;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;

@Data
public class IncidentDto {

    @NotBlank
    private String description;

    @NotBlank
    @Pattern(regexp = "OPEN|IN_PROGRESS|CLOSED")
    private String status;

    @NotEmpty // Ensures the list is not empty
    private List<String> incidentTypes; // ✅ Changed to List<String>

    // Getters and Setters
    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public List<String> getIncidentTypes() {
        return incidentTypes;
    }

    public void setIncidentTypes(List<String> incidentTypes) {
        this.incidentTypes = incidentTypes;
    }
}
