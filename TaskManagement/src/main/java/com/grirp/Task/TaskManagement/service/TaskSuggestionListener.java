package com.grirp.Task.TaskManagement.service;

import com.grirp.Task.TaskManagement.event.IncidentEvent;
import com.grirp.Task.TaskManagement.model.Task;
import com.grirp.Task.TaskManagement.repository.TaskRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.kafka.annotation.KafkaListener;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
public class TaskSuggestionListener {
    @Autowired
    private TaskRepository repo;

    @KafkaListener(topics = "incidents-topic", groupId = "task-group")
    public void listen(IncidentEvent event) {
        if ("CREATED".equals(event.getAction())) {
            List<String> incidentTypes = event.getIncidentTypes();
            if (incidentTypes != null && !incidentTypes.isEmpty()) {

                Set<Long> teamIds = new HashSet<>();
                for (String type : incidentTypes) {
                    Long teamId = getTeamIdForIncidentType(type);
                    if (teamId != null) {
                        teamIds.add(teamId);
                    }
                }

                // Create a task for each unique team
                for (Long teamId : teamIds) {
                    Task task = new Task();
                    task.setIncidentId(event.getIncidentId());
                    task.setTeamId(teamId);
                    task.setDescription("Respond to incident");
                    task.setStatus("PENDING");
                    repo.save(task);
                }
            }
        }
    }

    private Long getTeamIdForIncidentType(String incidentType) {
        if (incidentType == null) return null;
        switch (incidentType.toLowerCase()) {
            case "fire":
                return 1L; // Fire Department
            case "medical":
                return 2L; // Healthcare Department
            case "crime":
                return 3L; // Police Department
            case "ambulance":
                return 2L; // Healthcare Department (same as medical)
            default:
                return null; // Unknown types are ignored
        }
    }
}