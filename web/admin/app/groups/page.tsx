"use client"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
} from "@/components/ui/dialog"
import { Plus, Trash2, X, Pencil } from "lucide-react"

export default function GroupsPage() {
    const [groups, setGroups] = useState([])
    const [configs, setConfigs] = useState([])
    const [addDialogOpen, setAddDialogOpen] = useState(false)
    const [editDialogOpen, setEditDialogOpen] = useState(false)
    const [selectedGroup, setSelectedGroup] = useState<any>(null)
    const [formData, setFormData] = useState({ name: "", description: "" })

    const fetchGroups = () => {
        fetch('/api/groups', { cache: 'no-store' })
            .then(res => {
                if (!res.ok) throw new Error('Failed to fetch')
                return res.json()
            })
            .then(data => setGroups(data || []))
            .catch(err => console.error(err))
    }

    const fetchConfigs = () => {
        fetch('/api/configs', { cache: 'no-store' })
            .then(res => {
                if (!res.ok) throw new Error('Failed to fetch')
                return res.json()
            })
            .then(data => setConfigs(data || []))
            .catch(err => console.error(err))
    }

    useEffect(() => {
        fetchGroups()
        fetchConfigs()
    }, [])

    const handleAddGroup = async () => {
        await fetch('/api/groups', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(formData)
        })
        setAddDialogOpen(false)
        setFormData({ name: "", description: "" })
        fetchGroups()
    }

    const handleEditGroup = async () => {
        await fetch('/api/groups', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                id: selectedGroup.id,
                name: formData.name,
                description: formData.description
            })
        })
        setEditDialogOpen(false)
        fetchGroups()
    }

    const handleDeleteGroup = async (id: number) => {
        if (confirm('Delete this group?')) {
            await fetch(`/api/groups?id=${id}`, { method: 'DELETE' })
            fetchGroups()
        }
    }

    const [assignDialogOpen, setAssignDialogOpen] = useState(false)
    const [targetGroupId, setTargetGroupId] = useState<number | null>(null)
    const [selectedConfigId, setSelectedConfigId] = useState<string>("")

    const openAssignDialog = (groupId: number) => {
        setTargetGroupId(groupId)
        setSelectedConfigId("")
        setAssignDialogOpen(true)
    }

    const handleAssignConfigSubmit = async () => {
        if (targetGroupId && selectedConfigId) {
            await fetch('/api/groups/configs', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ group_id: targetGroupId, config_id: parseInt(selectedConfigId) })
            })
            setAssignDialogOpen(false)
            fetchGroups()
        }
    }

    const handleRemoveConfig = async (groupId: number, configId: number) => {
        if (!confirm("Unlink this config?")) return
        await fetch(`/api/groups/configs?group_id=${groupId}&config_id=${configId}`, { method: 'DELETE' })
        fetchGroups()
    }

    return (
        <div className="flex-1 space-y-4 p-8 pt-6">
            <div className="flex items-center justify-between">
                <h2 className="text-3xl font-bold tracking-tight">Subscription Groups</h2>
                <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
                    <DialogTrigger asChild>
                        <Button><Plus className="mr-2 h-4 w-4" /> Add Group</Button>
                    </DialogTrigger>
                    <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                        <DialogHeader>
                            <DialogTitle>Add New Group</DialogTitle>
                            <DialogDescription className="text-zinc-400">
                                Create a subscription plan.
                            </DialogDescription>
                        </DialogHeader>
                        <div className="grid gap-4 py-4">
                            <div className="grid gap-2">
                                <Label>Name</Label>
                                <Input className="bg-zinc-800 border-zinc-700" value={formData.name}
                                    onChange={(e) => setFormData({ ...formData, name: e.target.value })} placeholder="Premium Plan" />
                            </div>
                            <div className="grid gap-2">
                                <Label>Description</Label>
                                <Textarea className="bg-zinc-800 border-zinc-700" value={formData.description}
                                    onChange={(e) => setFormData({ ...formData, description: e.target.value })} placeholder="Multi-location access" />
                            </div>
                        </div>
                        <DialogFooter>
                            <Button onClick={handleAddGroup}>Create Group</Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>

                {/* Assign Config Dialog */}
                <Dialog open={assignDialogOpen} onOpenChange={setAssignDialogOpen}>
                    <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                        <DialogHeader>
                            <DialogTitle>Assign Config to Group</DialogTitle>
                            <DialogDescription className="text-zinc-400">
                                Select a core configuration to add to this group.
                            </DialogDescription>
                        </DialogHeader>
                        <div className="grid gap-4 py-4">
                            <div className="grid gap-2">
                                <Label>Select Config</Label>
                                <select
                                    className="flex h-10 w-full rounded-md border border-zinc-700 bg-zinc-800 px-3 py-2 text-sm ring-offset-zinc-900 placeholder:text-zinc-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-400 disabled:cursor-not-allowed disabled:opacity-50"
                                    value={selectedConfigId}
                                    onChange={(e) => setSelectedConfigId(e.target.value)}
                                >
                                    <option value="" disabled>Select a config...</option>
                                    {configs.map((c: any) => (
                                        <option key={c.id} value={c.id}>
                                            {c.name} ({c.protocol})
                                        </option>
                                    ))}
                                </select>
                            </div>
                        </div>
                        <DialogFooter>
                            <Button onClick={handleAssignConfigSubmit} disabled={!selectedConfigId}>Assign</Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>
            </div>

            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                {groups.map((group: any) => (
                    <Card key={group.id} className="bg-zinc-900 border-zinc-800 text-white">
                        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                            <CardTitle className="text-sm font-medium">{group.name}</CardTitle>
                            <div className="flex gap-1">
                                <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => {
                                    setSelectedGroup(group)
                                    setFormData({ name: group.name, description: group.description })
                                    setEditDialogOpen(true)
                                }}>
                                    <Pencil className="h-4 w-4" />
                                </Button>
                                <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => handleDeleteGroup(group.id)}>
                                    <Trash2 className="h-4 w-4 text-red-500" />
                                </Button>
                            </div>
                        </CardHeader>
                        <CardContent className="space-y-3">
                            <p className="text-xs text-zinc-400">{group.description}</p>

                            <div className="space-y-2">
                                <div className="flex items-center justify-between">
                                    <span className="text-xs text-zinc-500">Assigned Configs:</span>
                                    <Button variant="ghost" size="sm" onClick={() => openAssignDialog(group.id)} className="h-6 text-xs text-emerald-400 hover:text-emerald-300">
                                        <Plus className="h-3 w-3 mr-1" /> Add
                                    </Button>
                                </div>

                                <div className="flex flex-wrap gap-2">
                                    {(group.configs || []).map((c: any) => (
                                        <Badge key={c.id} variant="secondary" className="bg-zinc-800 text-zinc-300 border border-zinc-700 pr-1">
                                            {c.name}
                                            <button onClick={() => handleRemoveConfig(group.id, c.id)} className="ml-2 hover:text-red-400">
                                                <X className="h-3 w-3" />
                                            </button>
                                        </Badge>
                                    ))}
                                    {(!group.configs || group.configs.length === 0) && (
                                        <span className="text-xs text-zinc-600 italic">No configs assigned</span>
                                    )}
                                </div>
                            </div>
                        </CardContent>
                    </Card>
                ))}

                {groups.length === 0 && (
                    <div className="col-span-3 text-center text-zinc-500 py-8">
                        No groups found. Create your first subscription plan.
                    </div>
                )}
            </div>

            <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
                <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                    <DialogHeader>
                        <DialogTitle>Edit Group</DialogTitle>
                        <DialogDescription className="text-zinc-400">
                            Update subscription plan details.
                        </DialogDescription>
                    </DialogHeader>
                    <div className="grid gap-4 py-4">
                        <div className="grid gap-2">
                            <Label>Name</Label>
                            <Input className="bg-zinc-800 border-zinc-700" value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })} />
                        </div>
                        <div className="grid gap-2">
                            <Label>Description</Label>
                            <Textarea className="bg-zinc-800 border-zinc-700" value={formData.description}
                                onChange={(e) => setFormData({ ...formData, description: e.target.value })} />
                        </div>
                    </div>
                    <DialogFooter>
                        <Button onClick={handleEditGroup}>Save Changes</Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </div>
    )
}
