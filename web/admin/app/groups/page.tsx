"use client"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Checkbox } from "@/components/ui/checkbox"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
} from "@/components/ui/dialog"
import { Plus, Trash2, Pencil, Users, Lock, Unlock } from "lucide-react"
import {
    AlertDialog,
    AlertDialogAction,
    AlertDialogCancel,
    AlertDialogContent,
    AlertDialogDescription,
    AlertDialogFooter,
    AlertDialogHeader,
    AlertDialogTitle,
} from "@/components/ui/alert-dialog"

export default function GroupsPage() {
    const [groups, setGroups] = useState([])
    const [configs, setConfigs] = useState([])
    const [addDialogOpen, setAddDialogOpen] = useState(false)
    const [editDialogOpen, setEditDialogOpen] = useState(false)
    const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
    const [groupToDelete, setGroupToDelete] = useState<any>(null)
    const [selectedGroup, setSelectedGroup] = useState<any>(null)

    // Form Data: selectedTags is an array of tag strings
    const [formData, setFormData] = useState({
        name: "",
        tags: "",
        is_disabled: false
    })
    const [selectedTags, setSelectedTags] = useState<string[]>([])

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
            .then(res => res.json())
            .then(data => setConfigs(data || []))
            .catch(err => console.error(err))
    }

    useEffect(() => {
        fetchGroups()
        fetchConfigs()
    }, [])

    // Extract unique inbound tags from configs
    const getAvailableTags = () => {
        const tags = new Set<string>()
        configs.forEach((config: any) => {
            if (config.raw_inbounds) {
                try {
                    const parsed = JSON.parse(config.raw_inbounds)
                    const inbounds = Array.isArray(parsed) ? parsed : [parsed]
                    inbounds.forEach((inbound: any) => {
                        if (inbound.tag) tags.add(inbound.tag)
                    })
                } catch (e) {
                    // Skip invalid JSON
                }
            }
        })
        return Array.from(tags).sort()
    }

    const toggleTag = (tag: string) => {
        setSelectedTags(prev =>
            prev.includes(tag) ? prev.filter(t => t !== tag) : [...prev, tag]
        )
    }

    const handleAddGroup = async () => {
        await fetch('/api/groups', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                name: formData.name,
                inbound_tags: selectedTags,
                is_disabled: formData.is_disabled
            })
        })
        setAddDialogOpen(false)
        setFormData({ name: "", tags: "", is_disabled: false })
        setSelectedTags([])
        fetchGroups()
    }

    const handleEditGroup = async () => {
        await fetch('/api/groups', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                id: selectedGroup.id,
                name: formData.name,
                inbound_tags: selectedTags,
                is_disabled: formData.is_disabled
            })
        })
        setEditDialogOpen(false)
        fetchGroups()
    }

    const confirmDeleteGroup = (group: any) => {
        setGroupToDelete(group)
        setDeleteDialogOpen(true)
    }

    const executeDeleteGroup = async () => {
        if (!groupToDelete) return
        await fetch(`/api/groups?id=${groupToDelete.id}`, { method: 'DELETE' })
        setDeleteDialogOpen(false)
        setGroupToDelete(null)
        fetchGroups()
    }

    const openEdit = (group: any) => {
        setSelectedGroup(group)
        setFormData({
            name: group.name,
            tags: (group.inbound_tags || []).join(', '),
            is_disabled: group.is_disabled
        })
        setSelectedTags(group.inbound_tags || [])
        setEditDialogOpen(true)
    }

    return (
        <div className="flex-1 space-y-4 p-8 pt-6">
            <div className="flex items-center justify-between">
                <div>
                    <h2 className="text-3xl font-bold tracking-tight">Access Control Groups</h2>
                    <p className="text-zinc-400">Manage user access policies by grouping inbound tags.</p>
                </div>
                <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
                    <DialogTrigger asChild>
                        <Button className="bg-emerald-600 hover:bg-emerald-700 text-white">
                            <Plus className="mr-2 h-4 w-4" /> Create Group
                        </Button>
                    </DialogTrigger>
                    <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                        <DialogHeader>
                            <DialogTitle>Create Access Group</DialogTitle>
                            <DialogDescription className="text-zinc-400">
                                Define a group of inbound tags to share with users.
                            </DialogDescription>
                        </DialogHeader>
                        <div className="grid gap-4 py-4">
                            <div className="grid gap-2">
                                <Label>Group Name</Label>
                                <Input
                                    className="bg-zinc-800 border-zinc-700"
                                    value={formData.name}
                                    placeholder="e.g. Premium-VLESS"
                                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                />
                            </div>
                            <div className="grid gap-2">
                                <Label>Select Inbound Tags</Label>
                                <div className="max-h-48 overflow-y-auto space-y-2 p-3 bg-zinc-950 border border-zinc-700 rounded-md">
                                    {getAvailableTags().length === 0 && (
                                        <p className="text-xs text-zinc-500 text-center py-4">
                                            No inbound tags found. Ensure your Config Templates inbounds have a "tag" property.
                                        </p>
                                    )}
                                    {getAvailableTags().map(tag => (
                                        <div key={tag} className="flex items-center space-x-2 p-2 hover:bg-zinc-800 rounded">
                                            <Checkbox
                                                id={`tag-${tag}`}
                                                checked={selectedTags.includes(tag)}
                                                onCheckedChange={() => toggleTag(tag)}
                                            />
                                            <Label htmlFor={`tag-${tag}`} className="font-mono text-sm cursor-pointer flex-1">
                                                {tag}
                                            </Label>
                                        </div>
                                    ))}
                                </div>
                                <p className="text-[10px] text-zinc-500">
                                    Selected: {selectedTags.length === 0 ? "None" : selectedTags.join(", ")}
                                </p>
                            </div>
                            <div className="flex items-center space-x-2 pt-2">
                                <Checkbox
                                    id="disable-new"
                                    checked={formData.is_disabled}
                                    onCheckedChange={(checked) => setFormData({ ...formData, is_disabled: checked as boolean })}
                                />
                                <Label htmlFor="disable-new">Disable this group (revoke access)</Label>
                            </div>
                        </div>
                        <DialogFooter>
                            <Button onClick={handleAddGroup} className="bg-emerald-600 hover:bg-emerald-700">Create</Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>
            </div>

            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                {groups.map((group: any) => (
                    <Card key={group.id} className={`bg-zinc-900 border-zinc-800 text-white ${group.is_disabled ? 'opacity-60 border-dashed' : ''}`}>
                        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                            <div className="flex items-center gap-2">
                                {group.is_disabled ? <Lock className="h-4 w-4 text-red-500" /> : <Unlock className="h-4 w-4 text-emerald-500" />}
                                <CardTitle className="text-sm font-medium">{group.name}</CardTitle>
                            </div>
                            <div className="flex gap-1">
                                <Button variant="ghost" size="icon" className="h-7 w-7 hover:bg-zinc-800" onClick={() => openEdit(group)}>
                                    <Pencil className="h-4 w-4 text-zinc-400" />
                                </Button>
                                <Button variant="ghost" size="icon" className="h-7 w-7 hover:bg-zinc-800" onClick={() => confirmDeleteGroup(group)}>
                                    <Trash2 className="h-4 w-4 text-red-500" />
                                </Button>
                            </div>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            <div className="flex items-center gap-2 text-zinc-400 text-xs">
                                <Users className="h-3 w-3" />
                                <span>{group.total_users || 0} Users</span>
                            </div>

                            <div className="space-y-2">
                                <Label className="text-xs text-zinc-500 uppercase tracking-wider">Inbound Tags</Label>
                                <div className="flex flex-wrap gap-1.5">
                                    {(group.inbound_tags || []).map((tag: string, i: number) => (
                                        <Badge key={i} variant="secondary" className="bg-zinc-800 text-purple-300 border border-zinc-700 text-[10px] px-2 py-0.5 font-mono">
                                            {tag}
                                        </Badge>
                                    ))}
                                    {(!group.inbound_tags || group.inbound_tags.length === 0) && (
                                        <span className="text-xs text-zinc-600 italic">No tags assigned</span>
                                    )}
                                </div>
                            </div>
                        </CardContent>
                    </Card>
                ))}

                {groups.length === 0 && (
                    <div className="col-span-3 text-center text-zinc-500 py-12 border border-dashed border-zinc-800 rounded-lg">
                        <Layers className="h-8 w-8 mx-auto mb-2 opacity-50" />
                        <p>No groups found. Create a group to control user access.</p>
                    </div>
                )}
            </div>

            <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
                <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                    <DialogHeader>
                        <DialogTitle>Edit Group</DialogTitle>
                    </DialogHeader>
                    <div className="grid gap-4 py-4">
                        <div className="grid gap-2">
                            <Label>Name</Label>
                            <Input className="bg-zinc-800 border-zinc-700" value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })} />
                        </div>
                        <div className="grid gap-2">
                            <Label>Select Inbound Tags</Label>
                            <div className="max-h-48 overflow-y-auto space-y-2 p-3 bg-zinc-950 border border-zinc-700 rounded-md">
                                {getAvailableTags().length === 0 && (
                                    <p className="text-xs text-zinc-500 text-center py-4">
                                        No inbound tags found. Ensure your Config Templates inbounds have a "tag" property.
                                    </p>
                                )}
                                {getAvailableTags().map(tag => (
                                    <div key={tag} className="flex items-center space-x-2 p-2 hover:bg-zinc-800 rounded">
                                        <Checkbox
                                            id={`edit-tag-${tag}`}
                                            checked={selectedTags.includes(tag)}
                                            onCheckedChange={() => toggleTag(tag)}
                                        />
                                        <Label htmlFor={`edit-tag-${tag}`} className="font-mono text-sm cursor-pointer flex-1">
                                            {tag}
                                        </Label>
                                    </div>
                                ))}
                            </div>
                            <p className="text-[10px] text-zinc-500">
                                Selected: {selectedTags.length === 0 ? "None" : selectedTags.join(", ")}
                            </p>
                        </div>
                        <div className="flex items-center space-x-2 pt-2">
                            <Checkbox
                                id="disable-edit"
                                checked={formData.is_disabled}
                                onCheckedChange={(checked) => setFormData({ ...formData, is_disabled: checked as boolean })}
                            />
                            <Label htmlFor="disable-edit">Disable this group</Label>
                        </div>
                    </div>
                    <DialogFooter>
                        <Button onClick={handleEditGroup} className="bg-emerald-600 hover:bg-emerald-700">Save Changes</Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
                <AlertDialogContent className="bg-zinc-900 border-zinc-800 text-white">
                    <AlertDialogHeader>
                        <AlertDialogTitle>Delete Group?</AlertDialogTitle>
                        <AlertDialogDescription className="text-zinc-400">
                            This will permanently delete the group <strong>{groupToDelete?.name}</strong>.
                            Users assigned to this group will lose access to its inbounds.
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogCancel className="bg-zinc-800 border-zinc-700">Cancel</AlertDialogCancel>
                        <AlertDialogAction onClick={executeDeleteGroup} className="bg-red-600 hover:bg-red-700">
                            Delete
                        </AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>
        </div>
    )
}
import { Layers } from "lucide-react"
