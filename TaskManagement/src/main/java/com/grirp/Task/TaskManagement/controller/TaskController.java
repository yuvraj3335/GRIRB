package com.grirp.Task.TaskManagement.controller;

import com.grirp.Task.TaskManagement.model.Task;
import com.grirp.Task.TaskManagement.repository.TaskRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/tasks")
public class TaskController {

    @Autowired
    private TaskRepository repo;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Task create(@RequestBody Task task) {
        return repo.save(task);
    }

    @GetMapping
    public List<Task> list(@RequestParam( name = "teamId" , required = false) Long teamId, @AuthenticationPrincipal Jwt jwt) {
        String userTeamId = jwt.getClaimAsString("custom:teamId");
        if (userTeamId == null) {
            throw new RuntimeException("User has no team assigned in token");
        }

        List<String> groups = jwt.getClaimAsStringList("cognito:groups");
        boolean isAdmin = groups != null && groups.contains("ROLE_ADMIN");

        Long userTeamIdLong = Long.parseLong(userTeamId);

        if (isAdmin) {
            if (teamId != null) {
                return repo.findByTeamId(teamId);
            }
            return repo.findAll();
        }

        if (teamId != null && !teamId.equals(userTeamIdLong)) {
            throw new AccessDeniedException("You can only view tasks for your team");
        }
        return repo.findByTeamId(userTeamIdLong);
    }

    @PutMapping("/{id}")
    public Task update(@PathVariable("id") Long id, @RequestBody Task task) {
        Task existing = repo.findById(id).orElseThrow(() -> new RuntimeException("Task not found"));
        existing.setDescription(task.getDescription());
        existing.setStatus(task.getStatus());
        existing.setAssignee(task.getAssignee());
        return repo.save(existing);
    }
}